<?php

// todo: come back to this file

namespace Drupal\dg_autologout\Controller;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Core\Ajax\AjaxResponse;
use Drupal\Core\Ajax\ReplaceCommand;
use Drupal\Core\Ajax\SettingsCommand;
use Drupal\Core\Controller\ControllerBase;
use Drupal\Core\Url;
// ! this is one needed?
use Drupal\autologout\dg_AutologoutManagerInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\HttpFoundation\RequestStack;

/**
 * Returns responses for autologout module routes.
 */
class dg_AutologoutController extends ControllerBase {

  /**
   * The autologout manager service.
   *
   * @var \Drupal\dg_autologout\dg_AutologoutManagerInterface
   */
  protected $dg_autoLogoutManager;


  /**
   * The Time Service.
   *
   * @var \Drupal\Component\Datetime\TimeInterface
   */
  protected $time;

  /**
   * The request stack.
   *
   * @var \Symfony\Component\HttpFoundation\RequestStack
   */
  protected RequestStack $requestStack;

  /**
   * Constructs an AutologoutSubscriber object.
   *
   * @param \Drupal\dg_autologout\dg_AutologoutManagerInterface $dg_autologout
   *   The autologout manager service.
   * @param \Drupal\Component\Datetime\TimeInterface $time
   *   The time service.
   * @param \Symfony\Component\HttpFoundation\RequestStack $requestStack
   *   The request stack.
   */
  public function __construct(dg_AutologoutManagerInterface $dg_autologout, TimeInterface $time, RequestStack $requestStack) {
    $this->dg_autoLogoutManager = $dg_autologout;
    $this->time = $time;
    $this->requestStack = $requestStack;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('dg_autologout.manager'),
      $container->get('datetime.time'),
      $container->get('request_stack')
    );
  }

  /**
   * Alternative logout.
   */
  public function altLogout() {
    $redirect_url = $this->dg_autoLogoutManager->getUserRedirectUrl();
    $this->dg_autoLogoutManager->logout();
    $url = Url::fromUserInput(
      $redirect_url,
      [
        'absolute' => TRUE,
        'query' => [
          'dg_autologout_timeout' => 1,
        ],
      ]
    );

    return new RedirectResponse($url->toString());
  }

  /**
   * AJAX logout.
   */
  public function ajaxLogout() {
    $this->dg_autoLogoutManager->logout();
    $response = new AjaxResponse();
    $response->setStatusCode(200);

    return $response;
  }

  /**
   * Ajax callback to reset the last access session variable.
   */
  public function ajaxSetLast() {
    $this->requestStack->getCurrentRequest()->getSession()->set('dg_autologout_last', $this->time->getRequestTime());

    // Reset the timer.
    $response = new AjaxResponse();
    $markup = $this->autoLogoutManager->createTimer();
    $response->addCommand(new ReplaceCommand('#timer', $markup));
    $response->addCommand(new SettingsCommand(['activity' => TRUE]));

    return $response;
  }

  /**
   * AJAX callback that returns the time remaining for this user is logged out.
   */
  public function ajaxGetRemainingTime() {
    $req = $this->requestStack->getCurrentRequest();
    $active = $req->get('uactive');
    $response = new AjaxResponse();

    if (isset($active) && $active === "false") {
      $response->addCommand(new ReplaceCommand('#timer', 0));
      $response->addCommand(new SettingsCommand([
        'time' => 0,
        'activity' => FALSE,
      ]));

      return $response;
    }

    $time_remaining_ms = $this->autoLogoutManager->getRemainingTime() * 1000;

    // Reset the timer.
    $markup = $this->dg_autoLogoutManager->createTimer();

    $response->addCommand(new ReplaceCommand('#timer', $markup));
    $response->addCommand(new SettingsCommand([
      'time' => $time_remaining_ms,
      'activity' => TRUE,
    ]));

    return $response;
  }

}
