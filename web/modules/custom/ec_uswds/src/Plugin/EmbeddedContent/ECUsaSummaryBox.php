<?php

namespace Drupal\ec_uswds\Plugin\EmbeddedContent;

use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;
use Drupal\embedded_content\EmbeddedContentInterface;
use Drupal\embedded_content\EmbeddedContentPluginBase;

/**
 * Renders a USWDS summary box as embedded content.
 *
 * @EmbeddedContent(
 *   id = "ec_usasummarybox",
 *   label = @Translation("Summary Box"),
 *   description = @Translation("Highlights key information from the page."),
 * )
 */
class ECUsaSummaryBox extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      'heading' => 'Key information',
      'text' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_usasummarybox',
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
      '#title' => $this->t('Summary box heading'),
      '#default_value' => $this->configuration['heading'] ?? $this->t('Key information'),
      '#required' => TRUE,
    ];
    $form['text'] = [
      '#type' => 'text_format',
      '#title' => $this->t('Summary box content'),
      '#description' => $this->t('Use a short list of 3 to 5 key details. Do not use this as a table of contents.'),
      '#format' => $this->configuration['text']['format'] ?? 'html_embedded_content',
      '#allowed_formats' => ['html_embedded_content'],
      '#default_value' => $this->configuration['text']['value'] ?? '',
      '#required' => TRUE,
    ];
    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function isInline(): bool {
    return FALSE;
  }

}
