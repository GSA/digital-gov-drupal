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
 *   id = "ec_shortcodes_accordion",
 *   label = @Translation("Accordion"),
 *   description = @Translation("Renders an Accordion."),
 * )
 */
class ECShortcodesAccordion extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      'kicker' => NULL,
      'accordion_title' => NULL,
      'icon' => NULL,
      'text' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_shortcodes_accordion',
      '#kicker' => $this->configuration['kicker'],
      '#accordion_title' => $this->configuration['accordion_title'],
      '#icon' => $this->configuration['icon'],
      '#text' => $this->configuration['text'],
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    $form['kicker'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Kicker'),
      '#default_value' => $this->configuration['kicker'],
      '#required' => TRUE,
    ];
    $form['accordion_title'] = [
      '#type' => 'text_format',
      '#title' => $this->t('Title'),
      '#default_value' => $this->configuration['accordion_title']['value'] ?? '',
      '#format' => 'single_inline_html',
      '#allowed_formats' => ['single_inline_html'],
      '#required' => TRUE,
      '#rows' => 1,
    ];
    $form['icon'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Icon'),
      '#default_value' => $this->configuration['icon'],
      '#required' => TRUE,
    ];
    $form['text'] = [
      '#type' => 'text_format',
      '#title' => $this->t('Body'),
      '#default_value' => $this->configuration['text']['value'] ?? '',
      '#format' => 'html_embedded_content',
      '#allowed_formats' => ['html_embedded_content'],
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
