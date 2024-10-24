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
      'title' => NULL,
      'icon' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_shortcodes_accordion',
      '#kicker' => $this->configuration['kicker'],
      '#title' => $this->configuration['title'],
      '#icon' => $this->configuration['icon'],
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    $form['kicker'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Kicker'),
      '#default_value' => $this->configuration['text'],
      '#required' => TRUE,
    ];
    $form['title'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Title'),
      '#default_value' => $this->configuration['text'],
      '#required' => TRUE,
    ];
    $form['icon'] = [
      '#type' => 'media_library',
      '#title' => $this->t('Icon'),
      '#default_value' => $this->configuration['media_library'],
      '#required' => TRUE,
      '#media_types' => ['image'],
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
