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
 *   id = "ec_shortcodes_card_quote",
 *   label = @Translation("Quote"),
 *   description = @Translation("Renders an card styled quote."),
 * )
 */
class ECShortcodesCardQuote extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      'dark' => NULL,
      'text' => NULL,
      'cite' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_shortcodes_card_quote',
      '#dark' => $this->configuration['dark'],
      '#text' => $this->configuration['text'],
      '#cite' => $this->configuration['cite'],
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    $form['dark'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Display quote with alternative dark background.'),
      '#default_value' => $this->configuration['dark'],
    ];
    $form['text'] = [
      '#type' => 'text_format',
      '#title' => $this->t('Text'),
      '#default_value' => $this->configuration['text']['value'] ?? '',
      '#format' => 'single_inline_html',
      '#allowed_formats' => ['single_inline_html'],
      '#required' => TRUE,
      '#rows' => 1,
    ];
    $form['cite'] = [
      '#type' => 'text_format',
      '#title' => $this->t('Cite'),
      '#default_value' => $this->configuration['cite']['value'] ?? '',
      '#format' => 'single_inline_html',
      '#allowed_formats' => ['single_inline_html'],
      '#rows' => 1,
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
