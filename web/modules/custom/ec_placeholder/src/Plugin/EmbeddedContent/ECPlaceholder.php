<?php

namespace Drupal\ec_placeholder\Plugin\EmbeddedContent;

use Drupal\embedded_content\EmbeddedContentInterface;
use Drupal\embedded_content\EmbeddedContentPluginBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;

/**
 * Plugin iframes.
 *
 * @EmbeddedContent(
 *   id = "ec_placeholder",
 *   label = @Translation("Placeholder"),
 *   description = @Translation("Renders a placeholder for replacement."),
 * )
 */
class ECPlaceholder extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      'machine_name' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_placeholder',
      '#machine_name' => $this->configuration['machine_name'],
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    $form['machine_name'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Placeholder name'),
      '#default_value' => $this->configuration['machine_name'],
      '#required' => TRUE,
      '#description' => 'example: machine_name',
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
