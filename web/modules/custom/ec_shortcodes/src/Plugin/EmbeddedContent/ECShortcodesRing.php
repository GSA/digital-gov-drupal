<?php

namespace Drupal\ec_shortcodes\Plugin\EmbeddedContent;

use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;
use Drupal\embedded_content\EmbeddedContentInterface;
use Drupal\embedded_content\EmbeddedContentPluginBase;

/**
 * Plugin iframes.
 *
 * @EmbeddedContent(
 *   id = "ec_shortcodes_ring",
 *   label = @Translation("Ring"),
 *   description = @Translation("Renders a styled component."),
 * )
 */
class ECShortcodesRing extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      'heading' => NULL,
      'text' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_shortcodes_ring',
      '#heading' => $this->configuration['heading'],
      '#text' => $this->configuration['text'],
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    $form['heading'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Title'),
      '#default_value' => $this->configuration['heading'],
      '#required' => TRUE,
    ];
    $form['text'] = [
      '#type' => 'text_format',
      '#title' => $this->t('Body'),
      '#format' => 'html_embedded_content',
      '#allowed_formats' => ['html_embedded_content'],
      '#default_value' => $this->configuration['text']['value'] ?? '',
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
