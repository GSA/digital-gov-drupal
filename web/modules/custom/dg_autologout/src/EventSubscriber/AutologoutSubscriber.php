<?php

namespace Drupal\dg_autologout\EventSubscriber;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Core\Config\ConfigFactory;
use Drupal\Core\Language\LanguageManagerInterface;
use Drupal\Core\Session\AccountInterface;
use Drupal\Core\Theme\ThemeManager;
use Drupal\Core\Url;
use Drupal\dg_autologout\DgAutologoutManagerInterface;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * Defines autologout Subscriber.
 */
class AutologoutSubscriber implements EventSubscriberInterface {

  /**
   * The autologout manager service.
   *
   * @var \Drupal\dg_autologout\DgAutologoutManagerInterface
   */
  protected DgAutologoutManagerInterface $autologoutManager;

  /**
   * The user account service.
   *
   * @var \Drupal\Core\Session\AccountInterface
   */
  protected AccountInterface $currentUser;

  /**
   * The Config service.
   *
   * @var \Drupal\Core\Config\ConfigFactory
   */
  protected ConfigFactory $config;

  /**
   * The theme manager service.
   *
   * @var \Drupal\Core\Theme\ThemeManager
   */
  protected ThemeManager $theme;

  /**
   * The Time Service.
   *
   * @var \Drupal\Component\Datetime\TimeInterface
   */
  protected TimeInterface $time;

  /**
   * The request stacks service.
   *
   * @var \Symfony\Component\HttpFoundation\RequestStack
   */
  protected RequestStack $requestStack;

  /**
   * The language manager.
   *
   * @var \Drupal\Core\Language\LanguageManagerInterface
   */
  protected LanguageManagerInterface $languageManager;

  /**
   * Constructs an AutologoutSubscriber object.
   *
   * @param \Drupal\dg_autologout\DgAutologoutManagerInterface $dg_autologout
   *   The autologout manager service.
   * @param \Drupal\Core\Session\AccountInterface $account
   *   The user account service.
   * @param \Drupal\Core\Config\ConfigFactory $config
   *   The Config service.
   * @param \Drupal\Core\Theme\ThemeManager $theme
   *   The theme manager service.
   * @param \Drupal\Component\Datetime\TimeInterface $time
   *   The time service.
   * @param \Symfony\Component\HttpFoundation\RequestStack $requestStack
   *   The request stack service.
   * @param \Drupal\Core\Language\LanguageManagerInterface $language_manager
   *   The language manager.
   */
  public function __construct(DgAutologoutManagerInterface $dg_autologout, AccountInterface $account, ConfigFactory $config, ThemeManager $theme, TimeInterface $time, RequestStack $requestStack, LanguageManagerInterface $language_manager) {
    $this->autologoutManager = $dg_autologout;
    $this->currentUser = $account;
    $this->config = $config;
    $this->theme = $theme;
    $this->time = $time;
    $this->requestStack = $requestStack;
    $this->languageManager = $language_manager;
  }

  /**
   * Check for dg_autologout JS.
   *
   * @param \Symfony\Component\HttpKernel\Event\RequestEvent $event
   *   The request event.
   */
  public function onRequest(RequestEvent $event) {
    $dg_autologout_manager = $this->autologoutManager;

    $uid = $this->currentUser->id();

    if ($uid == 0) {
      $dg_autologout_timeout = $this->requestStack->getCurrentRequest()->query->get('dg_autologout_timeout');
      $post = $this->requestStack->getCurrentRequest()->request->all();
      if (!empty($dg_autologout_timeout) && $dg_autologout_timeout == 1 && empty($post)) {
        $dg_autologout_manager->inactivityMessage();
      }
      return;
    }

    // If user is not anonymous.
    $session = $this->requestStack->getCurrentRequest()->hasSession()
      ? $this->requestStack->getCurrentRequest()->getSession()
      : NULL;
    $auto_redirect = $session ? $session->get('auto_redirect') : NULL;

    // If http referer url has 'destination' and session is not set,
    // then only redirect to user page if uid doesn't match.
    if (empty($auto_redirect) && ($destination = $this->getDestination())) {
      $match = preg_match('#^destination=(/[a-z]+)?/user/([0-9]+)$#', $destination, $matches);

      if ($match && $matches[2] != $uid) {
        $session->set('auto_redirect', 1);
        $login_url = Url::fromRoute('user.page', [], ['absolute' => TRUE])->toString();

        // Redirect user to user page.
        $response = new RedirectResponse($login_url);
        $event->setResponse($response);
      }
    }

    if ($this->autologoutManager->preventJs()) {
      return;
    }

    $now = $this->time->getRequestTime();
    // Check if anything wants to be refresh only. This URL would include the
    // javascript but will keep the login alive whilst that page is opened.
    $refresh_only = $dg_autologout_manager->refreshOnly();
    $timeout = $dg_autologout_manager->getUserTimeout();
    $timeout_padding = $this->config->get('dg_autologout.settings')->get('padding');
    $is_altlogout = strpos($event->getRequest()->getRequestUri(), '/dg_autologout_alt_logout') !== FALSE;

    // We need a backup plan if JS is disabled.
    $session = $this->requestStack->getCurrentRequest()->getSession()->get('dg_autologout_last');
    if (!$is_altlogout && !$refresh_only && isset($session)) {
      // If time since last access is > timeout + padding, log them out.
      $diff = $now - $session;
      if ($diff >= ($timeout + (int) $timeout_padding)) {
        $dg_autologout_manager->logout();
        // User has changed so force Drupal to remake decisions based on user.
        global $theme, $theme_key;
        drupal_static_reset();
        $theme = NULL;
        $theme_key = NULL;
        $this->theme->getActiveTheme();
        $dg_autologout_manager->inactivityMessage();
      }
      else {
        $this->requestStack->getCurrentRequest()->getSession()->set('dg_autologout_last', $now);
      }
    }
    else {
      $this->requestStack->getCurrentRequest()->getSession()->set('dg_autologout_last', $now);
    }
  }

  /**
   * {@inheritdoc}
   */
  public static function getSubscribedEvents(): array {
    $events[KernelEvents::REQUEST][] = ['onRequest', 100];

    return $events;
  }

  /**
   * Get destination from referer.
   *
   * @return string|null
   *   The destination query string or null.
   */
  private function getDestination(): ?string {
    $request = $this->requestStack->getCurrentRequest();
    if (!$referer = $request->server->get('HTTP_REFERER')) {
      return NULL;
    }
    // Get query string from http referer url.
    $referer_parts = parse_url($referer, PHP_URL_QUERY);
    if (!empty($referer_parts) && str_contains($referer_parts, 'destination')) {
      return $referer_parts;
    }
    return FALSE;
  }

}
