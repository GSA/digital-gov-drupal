<?php

namespace Drupal\dg_autologout\Form;

use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\dg_autologout\DgAutologoutManagerInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Provides a settings for autologout module.
 */
class AutologoutBlockForm extends FormBase {

  /**
   * The autologout manager service.
   *
   * @var \Drupal\dg_autologout\DgAutologoutManagerInterface
   */
  protected $autologoutManager;

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'dg_autologout_block_settings';
  }

  /**
   * Constructs an AutologoutBlockForm object.
   *
   * @param \Drupal\dg_autologout\DgAutologoutManagerInterface $dg_autologout
   *   The autologout manager service.
   */
  public function __construct(DgAutologoutManagerInterface $dg_autologout) {
    $this->autologoutManager = $dg_autologout;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new self(
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
      '#markup' => $this->autologoutManager->createTimer(),
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
