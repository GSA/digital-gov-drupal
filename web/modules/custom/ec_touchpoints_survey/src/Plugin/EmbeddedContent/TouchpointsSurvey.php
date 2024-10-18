<?php

namespace Drupal\ec_touchpoints_survey\Plugin\EmbeddedContent;

use Drupal\embedded_content\EmbeddedContentInterface;
use Drupal\embedded_content\EmbeddedContentPluginBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;

/**
 * Plugin iframes.
 *
 * @EmbeddedContent(
 *   id = "touchpoints_survey",
 *   label = @Translation("Touchpoints survey"),
 *   description = @Translation("Renders a Touchpoints survey."),
 * )
 */
class TouchpointsSurvey extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      'file_name' => NULL,
      'id' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_touchpoints_survey',
      '#file_name' => $this->configuration['file_name'],
      '#id' => $this->configuration['id'],
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    $form['file_name'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Touchpoints js file name'),
      '#default_value' => $this->configuration['file_name'],
      '#required' => TRUE,
      '#description' => 'example: x1678367.js',
    ];
    $form['id'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Div target ID'),
      '#default_value' => $this->configuration['id'],
      '#required' => TRUE,
    ];
    return $form;
  }

  /**
   * {@inheritDoc}
   */
  public function isInline(): bool {
    return FALSE;
  }

}
