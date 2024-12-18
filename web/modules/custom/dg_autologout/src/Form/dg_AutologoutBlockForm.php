<?php

namespace Drupal\dg_autologout\Form;

use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\dg_autologout\dg_AutologoutManagerInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Provides a settings for autologout module.
 */
class dg_AutologoutBlockForm extends FormBase {

  /**
   * The autologout manager service.
   *
   * @var \Drupal\dg_autologout\dg_AutologoutManagerInterface
   */
  protected $dg_autoLogoutManager;

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'dg_autologout_block_settings';
  }

  /**
   * Constructs an AutologoutBlockForm object.
   *
   * @param \Drupal\dg_autologout\dg_AutologoutManagerInterface $dg_autologout
   *   The autologout manager service.
   */
  public function __construct(dg_AutologoutManagerInterface $dg_autologout) {
    $this->dg_autoLogoutManager = $dg_autologout;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('dg_autologout.manager')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $form['reset'] = [
      '#type' => 'button',
      '#value' => $this->t('Reset Timeout'),
      '#weight' => 1,
      '#limit_validation_errors' => FALSE,
      '#executes_submit_callback' => FALSE,
      '#ajax' => [
        'callback' => 'dg_autologout_ajax_set_last',
      ],
    ];

    $form['timer'] = [
      '#markup' => $this->dg_autoLogoutManager->createTimer(),
    ];

    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    // Submits on block form.
  }

}
