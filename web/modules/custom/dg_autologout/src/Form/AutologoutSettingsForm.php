<?php

namespace Drupal\dg_autologout\Form;

use Drupal\Core\Config\ConfigFactoryInterface;
use Drupal\Core\Config\TypedConfigManager;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Extension\ModuleHandlerInterface;
use Drupal\Core\Form\ConfigFormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\Messenger\MessengerInterface;
use Drupal\Core\Session\AccountInterface;
use Drupal\user\UserData;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Provides settings for autologout module.
 */
class AutologoutSettingsForm extends ConfigFormBase {

  /**
   * Defines the timeout limit.
   *
   * @var int
   *
   * Because we're using Javascript's setTimeout,
   * we must limit the timeout to a maximum of 2147483 seconds.
   * This is due to the fact that most, if not all, browsers store the
   * timeout value (in milliseconds) as a 32-bit signed integer.
   * An overflow then causes setTimeout to trigger immediately.
   *
   * More at: https://developer.mozilla.org/en-US/docs/Web/API/setTimeout
   */
  private $maxAllowedTimeout = 2147483;

  /**
   * The module manager service.
   *
   * @var \Drupal\Core\Extension\ModuleHandlerInterface
   */
  protected $moduleHandler;

  /**
   * The user.data service.
   *
   * @var \Drupal\user\UserDataInterface
   */
  protected $userData;

  /**
   * The EntityTypeManager service.
   *
   * @var \Drupal\Core\Entity\EntityTypeManagerInterface
   */
  protected $entityTypeManager;

  /**
   * Constructs an AutologoutSettingsForm object.
   *
   * @param \Drupal\Core\Config\ConfigFactoryInterface $config_factory
   *   The factory for configuration objects.
   * @param \Drupal\Core\Config\TypedConfigManager $config_typed
   *   The typed config object.
   * @param \Drupal\Core\Extension\ModuleHandlerInterface $module_handler
   *   The module manager service.
   * @param \Drupal\user\UserData $user_data
   *   The user.data service.
   * @param \Drupal\Core\Entity\EntityTypeManagerInterface $entity_type_manager
   *   The entity type manager.
   */
  public function __construct(ConfigFactoryInterface $config_factory, TypedConfigManager $config_typed, ModuleHandlerInterface $module_handler, UserData $user_data, EntityTypeManagerInterface $entity_type_manager) {
    parent::__construct($config_factory, $config_typed);
    $this->moduleHandler = $module_handler;
    $this->userData = $user_data;
    $this->entityTypeManager = $entity_type_manager;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new self(
      $container->get('config.factory'),
      $container->get('config.typed'),
      $container->get('module_handler'),
      $container->get('user.data'),
      $container->get('entity_type.manager')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function getEditableConfigNames() {
    return ['dg_autologout.settings'];
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'dg_autologout_settings';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config('dg_autologout.settings');
    $default_dialog_title = $config->get('dialog_title');
    if (!$default_dialog_title) {
      $default_dialog_title = $this->config('system.site')->get('name') . ' Alert';
    }

    $form['enabled'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Enable autologout'),
      '#default_value' => $config->get('enabled'),
      '#weight' => -20,
      '#description' => $this->t("Enable autologout on this site."),
    ];

    $form['timeout'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Timeout value in seconds'),
      '#default_value' => $config->get('timeout'),
      '#size' => 8,
      '#weight' => -10,
      '#description' => $this->t('The length of inactivity time, in seconds, before automated log out. Must be 60 seconds or greater. Will not be used if role timeout is activated.'),
    ];

    $form['max_timeout'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Max timeout setting'),
      '#default_value' => $config->get('max_timeout'),
      '#size' => 10,
      '#maxlength' => 12,
      '#weight' => -8,
      '#description' => $this->t('The maximum logout threshold time that can be set by users who have the permission to set user level timeouts.'),
    ];

    $form['padding'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Timeout padding'),
      '#default_value' => $config->get('padding'),
      '#size' => 8,
      '#weight' => -6,
      '#description' => $this->t('How many seconds to give a user to respond to the logout dialog before ending their session.'),
    ];

    $form['logout_regardless_of_activity'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Logout user regardless of activity'),
      '#default_value' => $config->get('logout_regardless_of_activity'),
      '#weight' => -5,
      '#description' => $this->t("Enable this to autologout user regardless of their activity."),
    ];

    $form['no_individual_logout_threshold'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Disable user-specific logout thresholds'),
      '#default_value' => $config->get('no_individual_logout_threshold'),
      '#weight' => -5,
      '#description' => $this->t("Enable this to only allow autologout thresholds to be set globally on this form and don't allow users to set their own logout threshold."),
    ];

    $form['role_logout'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Role Timeout'),
      '#default_value' => $config->get('role_logout'),
      '#weight' => -4,
      '#description' => $this->t('Enable each role to have its own timeout threshold and redirect URL, a refresh may be required for changes to take effect. Any role not ticked will use the default timeout value and default redirect URL. Any role can have a timeout value of 0 which means that they will never be logged out. Roles without specified redirect URL will use the default redirect URL.'),
    ];

    $form['role_logout_max'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Use highest role timeout value'),
      '#default_value' => $config->get('role_logout_max'),
      '#description' => $this->t('Check this to use the highest timeout value instead of the lowest for users that have more than one role.'),
      '#states' => [
        'visible' => [
          // Only show this field when the 'role_logout' checkbox is enabled.
          ':input[name="role_logout"]' => ['checked' => TRUE],
        ],
      ],
    ];

    $form['redirect_url'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Redirect URL at logout'),
      '#default_value' => $config->get('redirect_url'),
      '#size' => 40,
      '#description' => $this->t('Send users to this internal page when they are logged out.'),
    ];

    $form['include_destination'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Include destination'),
      '#default_value' => $config->get('include_destination'),
      '#description' => $this->t('Enable this if you want to set the redirect destination.'),
    ];

    $form['no_dialog'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Do not display the logout dialog'),
      '#default_value' => $config->get('no_dialog'),
      '#description' => $this->t('Enable this if you want users to logout right away and skip displaying the logout dialog.'),
    ];

    $form['use_alt_logout_method'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Use alternate logout method'),
      '#default_value' => $config->get('use_alt_logout_method'),
      '#description' => $this->t('Normally when auto logout is triggered, it is done via an AJAX service call. Sites that use an SSO provider, such as CAS, are likely to see this request fail with the error "Origin is not allowed by Access-Control-Allow-Origin". The alternate approach is to have the auto logout trigger a page redirect to initiate the logout process instead.'),
    ];

    $form['dialog_title'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Dialog title'),
      '#default_value' => $default_dialog_title,
      '#size' => 40,
      '#description' => $this->t('This text will be dialog box title.'),
    ];

    $form['message'] = [
      '#type' => 'textarea',
      '#title' => $this->t('Message to display in the logout dialog'),
      '#default_value' => $config->get('message'),
      '#size' => 40,
      '#description' => $this->t('This message must be plain text as it might appear in a JavaScript confirm dialog.'),
    ];

    $form['inactivity_message'] = [
      '#type' => 'textarea',
      '#title' => $this->t('Message to display to the user after they are logged out'),
      '#default_value' => $config->get('inactivity_message'),
      '#size' => 40,
      '#description' => $this->t('This message is displayed after the user was logged out due to inactivity. You can leave this blank to show no message to the user.'),
    ];

    $form['inactivity_message_type'] = [
      '#type' => 'select',
      '#title' => $this->t('Type of the message to display'),
      '#default_value' => $config->get('inactivity_message_type'),
      '#description' => $this->t('Specifies whether to display the message as status or warning.'),
      '#options' => [
        MessengerInterface::TYPE_STATUS => $this->t('Status'),
        MessengerInterface::TYPE_WARNING => $this->t('Warning'),
      ],
    ];

    $form['modal_width'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Modal width'),
      '#default_value' => $config->get('modal_width'),
      '#size' => 40,
      '#description' => $this->t('This modal dialog width in pixels.'),
    ];

    $form['disable_buttons'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Disable buttons'),
      '#default_value' => $config->get('disable_buttons'),
      '#description' => $this->t('Disable Yes/No buttons for automatic logout popout.'),
    ];

    $form['yes_button'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Custom confirm button text'),
      '#default_value' => $config->get('yes_button'),
      '#size' => 40,
      '#description' => $this->t('Add custom text to confirmation button.'),
    ];

    $form['no_button'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Custom decline button text'),
      '#default_value' => $config->get('no_button'),
      '#size' => 40,
      '#description' => $this->t('Add custom text to decline button.'),
    ];

    $form['use_watchdog'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Enable watchdog Automated Logout logging'),
      '#default_value' => $config->get('use_watchdog'),
      '#description' => $this->t('Enable logging of automatically logged out users'),
    ];

    $form['enforce_admin'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Enforce auto logout on admin pages'),
      '#default_value' => $config->get('enforce_admin'),
      '#description' => $this->t('If checked, then users will be automatically logged out when administering the site.'),
    ];
    $form['whitelisted_ip_addresses'] = [
      '#type' => 'textarea',
      '#title' => $this->t('Whitelisted ip addresses'),
      '#default_value' => $config->get('whitelisted_ip_addresses'),
      '#size' => 40,
      '#description' => $this->t('Users from these IP addresses will not be logged out.'),
    ];
    if ($this->moduleHandler->moduleExists('jstimer') && $this->moduleHandler->moduleExists('jst_timer')) {
      $form['jstimer_format'] = [
        '#type' => 'textfield',
        '#title' => $this->t('Autologout block time format'),
        '#default_value' => $config->get('jstimer_format'),
        '#description' => $this->t('Change the display of the dynamic timer. Available replacement values are: %day%, %month%, %year%, %dow%, %moy%, %years%, %ydays%, %days%, %hours%, %mins%, and %secs%.'),
      ];
    }

    $form['role_container'] = [
      '#type' => 'container',
      '#weight' => -2,
      '#states' => [
        'visible' => [
          // Only show this field when the 'role_logout' checkbox is enabled.
          ':input[name="role_logout"]' => ['checked' => TRUE],
        ],
      ],
    ];

    $form['role_container']['table'] = [
      '#type' => 'table',
      '#header' => [
        'enable' => $this->t('Customize'),
        'name' => $this->t('Role Name'),
        'timeout' => $this->t('Timeout (seconds)'),
        'url' => $this->t('Redirect URL at logout'),
      ],
    ];

    foreach ($this->entityTypeManager->getStorage('user_role')->loadMultiple() as $key => $role) {
      if ($key !== AccountInterface::ANONYMOUS_ROLE) {
        $form['role_container']['table'][$key] = [
          'enabled' => [
            '#type' => 'checkbox',
            '#default_value' => $this->config('autologout.role.' . $key)->get('enabled'),
          ],
          'role' => [
            '#type' => 'item',
            '#value' => $key,
            '#markup' => $key,
          ],
          'timeout' => [
            '#type' => 'textfield',
            '#default_value' => $this->config('autologout.role.' . $key)->get('timeout'),
            '#size' => 8,
          ],
          'url' => [
            '#type' => 'textfield',
            '#default_value' => $this->config('autologout.role.' . $key)->get('url'),
            '#size' => 40,
          ],
        ];
      }
    }

    return parent::buildForm($form, $form_state);
  }

  /**
   * Validate timeout range.
   *
   * Checks to see if timeout threshold is outside max/min values. Done here
   * to centralize and stop repeated code. Hard coded min, configurable max.
   *
   * @param int $timeout
   *   The timeout value in seconds to validate.
   * @param int $max_timeout
   *   (optional) Maximum value of timeout. If not set, system default is used.
   *
   * @return bool
   *   Return TRUE or FALSE
   */
  public function timeoutValidate($timeout, $max_timeout = NULL) {
    $validate = TRUE;
    if (is_null($max_timeout)) {
      $max_timeout = $this->config('autologout.settings')->get('max_timeout');
    }

    if (!is_numeric($timeout) || $timeout < 0 || ($timeout > 0 && $timeout < 60) || $timeout > $max_timeout) {
      // Less than 60, greater than max_timeout and is numeric.
      // 0 is allowed now as this means no timeout.
      $validate = FALSE;
    }
    return $validate;
  }

  /**
   * {@inheritdoc}
   */
  public function validateForm(array &$form, FormStateInterface $form_state) {
    $values = $form_state->getValues();
    $new_stack = [];
    if (!empty($values['table'])) {
      foreach ($values['table'] as $key => $pair) {
        if (is_array($pair)) {
          foreach ($pair as $pairkey => $pairvalue) {
            $new_stack[$key][$pairkey] = $pairvalue;
          }
        }
      }
    }

    $max_timeout = $values['max_timeout'];

    if ($values['role_logout']) {
      // Validate timeouts for each role.
      foreach (array_keys($this->entityTypeManager->getStorage('user_role')->loadMultiple()) as $role) {
        if (empty($new_stack[$role]) || $new_stack[$role]['enabled'] == 0) {
          // Don't validate role timeouts for non enabled roles.
          continue;
        }

        $timeout = $new_stack[$role]['timeout'];
        $validate = $this->timeoutValidate($timeout, $max_timeout);
        if (!$validate) {
          // phpcs:ignore
          $form_state->setErrorByName('table][' . $role . '][timeout', $this->t('%role role timeout must be an integer greater than 60, less then %max or 0 to disable autologout for that role.', ['%role' => $role, '%max' => $max_timeout]));
        }
        $role_redirect_url = $new_stack[$role]['url'];
        if (!empty($role_redirect_url) && strpos($role_redirect_url, '/') !== 0) {
          // phpcs:ignore
          $form_state->setErrorByName('table][' . $role . '][url', $this->t("%role role redirect URL at logout :redirect_url must begin with a '/'", ['%role' => $role, ':redirect_url' => $role_redirect_url]));
        }
      }
    }

    $timeout = $values['timeout'];
    // Validate timeout.
    if ($timeout < 60) {
      $form_state->setErrorByName('timeout', $this->t('The timeout value must be an integer 60 seconds or greater.'));
    }
    elseif ($max_timeout <= 60) {
      $form_state->setErrorByName('max_timeout', $this->t('The max timeout must be an integer greater than 60.'));
    }
    elseif ($max_timeout > $this->maxAllowedTimeout) {
      $form_state->setErrorByName('max_timeout', $this->t('The max timeout must be an integer lower than or equal to %limit.', ['%limit' => $this->maxAllowedTimeout]));
    }
    elseif (!is_numeric($timeout) || ((int) $timeout != $timeout) || $timeout < 60 || $timeout > $max_timeout) {
      $form_state->setErrorByName('timeout', $this->t('The timeout must be an integer greater than or equal to 60 and less then or equal to %max.', ['%max' => $max_timeout]));
    }

    $redirect_url = $values['redirect_url'];

    // Validate redirect url.
    if (strpos($redirect_url, '/') !== 0) {
      $form_state->setErrorByName('redirect_url', $this->t("Redirect URL at logout :redirect_url must begin with a '/'", [':redirect_url' => $redirect_url]));
    }
    // Validate ip address list.
    $whitelisted_ip_addresses_list = explode("\n", trim($values['whitelisted_ip_addresses']));

    foreach ($whitelisted_ip_addresses_list as $ip_address) {
      if (!empty($ip_address) && !filter_var(trim($ip_address), FILTER_VALIDATE_IP)) {
        $form_state->setErrorByName(
          'whitelisted_ip_addresses',
          $this->t('Whitlelisted IP address list should contain only valid IP addresses, one per row')
        );
      }
    }
    parent::validateForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    $values = $form_state->getValues();
    $dg_autologout_settings = $this->config('dg_autologout.settings');

    $old_no_individual_logout_threshold = $dg_autologout_settings->get('no_individual_logout_threshold');
    $new_no_individual_logout_threshold = (bool) $values['no_individual_logout_threshold'];

    $dg_autologout_settings
      ->set('enabled', $values['enabled'])
      ->set('timeout', $values['timeout'])
      ->set('max_timeout', $values['max_timeout'])
      ->set('padding', $values['padding'])
      ->set('no_individual_logout_threshold', $values['no_individual_logout_threshold'])
      ->set('logout_regardless_of_activity', $values['logout_regardless_of_activity'])
      ->set('role_logout', $values['role_logout'])
      ->set('role_logout_max', $values['role_logout_max'])
      ->set('redirect_url', $values['redirect_url'])
      ->set('include_destination', $values['include_destination'])
      ->set('no_dialog', $values['no_dialog'])
      ->set('dialog_title', $values['dialog_title'])
      ->set('message', $values['message'])
      ->set('inactivity_message', $values['inactivity_message'])
      ->set('inactivity_message_type', $values['inactivity_message_type'])
      ->set('modal_width', $values['modal_width'])
      ->set('disable_buttons', $values['disable_buttons'])
      ->set('yes_button', $values['yes_button'])
      ->set('no_button', $values['no_button'])
      ->set('enforce_admin', $values['enforce_admin'])
      ->set('whitelisted_ip_addresses', $values['whitelisted_ip_addresses'])
      ->set('use_alt_logout_method', $values['use_alt_logout_method'])
      ->set('use_watchdog', $values['use_watchdog'])
      ->save();

    if (!empty($values['table'])) {
      foreach ($values['table'] as $user) {
        $this->configFactory()->getEditable('dg_autologout.role.' . $user['role'])
          ->set('enabled', $user['enabled'])
          ->set('timeout', $user['timeout'])
          ->set('url', $user['url'])
          ->save();
      }
    }

    if (isset($values['jstimer_format'])) {
      $dg_autologout_settings->set('jstimer_format', $values['jstimer_format'])->save();
    }

    // If individual logout threshold setting is no longer enabled,
    // clear existing individual timeouts from users.
    if ($old_no_individual_logout_threshold === FALSE && $new_no_individual_logout_threshold === TRUE) {
      $users_timeout = $this->userData->get('dg_autologout', NULL, 'timeout');
      foreach ($users_timeout as $uid => $current_timeout_value) {
        if ($current_timeout_value !== NULL) {
          $this->userData->set('dg_autologout', $uid, 'timeout', NULL);
        }
      }
    }

    parent::submitForm($form, $form_state);
  }

}
