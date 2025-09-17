<?php

namespace Drupal\dg_autologout\Plugin\Block;

use Drupal\Core\Block\BlockBase;
use Drupal\Core\Config\Config;
use Drupal\Core\Datetime\DateFormatterInterface;
use Drupal\Core\Extension\ModuleHandlerInterface;
use Drupal\Core\Form\FormBuilder;
use Drupal\Core\Plugin\ContainerFactoryPluginInterface;
use Drupal\dg_autologout\AutologoutManager;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Provides an 'Automated Logout info' block.
 *
 * @Block(
 *   id = "dg_autologout_warning_block",
 *   admin_label = @Translation("Automated logout info"),
 *   category = @Translation("User"),
 * )
 */
class AutologoutWarningBlock extends BlockBase implements ContainerFactoryPluginInterface {

  /**
   * The module manager service.
   *
   * @var \Drupal\Core\Extension\ModuleHandlerInterface
   */
  protected $moduleHandler;

  /**
   * The date formatter service.
   *
   * @var \Drupal\Core\Datetime\DateFormatterInterface
   */
  protected $dateFormatter;

  /**
   * The config object for 'dg_autologout.settings'.
   *
   * @var \Drupal\Core\Config\Config
   */
  protected $autoLogoutSettings;

  /**
   * The AutologoutManager service.
   *
   * @var \Drupal\dg_autologout\AutologoutManager
   */
  protected $manager;

  /**
   * The FormBuilder service.
   *
   * @var \Drupal\Core\Form\FormBuilder
   */
  protected $builder;

  /**
   * Constructs an AutologoutWarningBlock object.
   *
   * @param array $configuration
   *   A configuration array containing information about the plugin instance.
   * @param string $plugin_id
   *   The plugin_id for the plugin instance.
   * @param string $plugin_definition
   *   The plugin implementation definition.
   * @param \Drupal\Core\Extension\ModuleHandlerInterface $module_handler
   *   The module manager service.
   * @param \Drupal\Core\Datetime\DateFormatterInterface $date_formatter
   *   The date formatter service.
   * @param \Drupal\Core\Config\Config $dg_autologout_settings
   *   The config object for 'dg_autologout.settings'.
   * @param \Drupal\dg_autologout\AutologoutManager $manager
   *   The AutologoutManager service.
   * @param \Drupal\Core\Form\FormBuilder $builder
   *   The FormBuilder service.
   */
  public function __construct(array $configuration, $plugin_id, $plugin_definition, ModuleHandlerInterface $module_handler, DateFormatterInterface $date_formatter, Config $dg_autologout_settings, AutologoutManager $manager, FormBuilder $builder) {
    parent::__construct($configuration, $plugin_id, $plugin_definition);
    $this->moduleHandler = $module_handler;
    $this->dateFormatter = $date_formatter;
    $this->autoLogoutSettings = $dg_autologout_settings;
    $this->manager = $manager;
    $this->builder = $builder;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container, array $configuration, $plugin_id, $plugin_definition) {
    return new self(
      $configuration,
      $plugin_id,
      $plugin_definition,
      $container->get('module_handler'),
      $container->get('date.formatter'),
      $container->get('config.factory')->get('dg_autologout.settings'),
      $container->get('dg_autologout.manager'),
      $container->get('form_builder'),
    );
  }

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    // @todo This is not the place where we should be doing this.
    $return = [];
    return $return;
  }

  /**
   * {@inheritdoc}
   */
  public function build() {
    $dg_autologout_manager = $this->manager;
    if ($dg_autologout_manager->preventJs()) {

      // Don't display the block if the user is not going
      // to be logged out on this page.
      return [];
    }

    if ($dg_autologout_manager->refreshOnly()) {
      $markup = $this->t('Autologout does not apply on the current page,
         you will be kept logged in whilst this page remains open.');
    }
    elseif ($this->moduleHandler->moduleExists('jstimer') && $this->moduleHandler->moduleExists('jst_timer')) {
      return $this->builder->getForm('Drupal\dg_autologout\Form\AutologoutBlockForm');
    }
    else {
      $timeout = (int) $dg_autologout_manager->getUserTimeout();
      $markup = $this->t('You will be logged out in @time if this page is not refreshed before then.', ['@time' => $this->dateFormatter->formatInterval($timeout)]);
    }

    return [
      '#type' => 'markup',
      '#markup' => $markup,
    ];
  }

}
