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
 *   id = "ec_shortcodes_featured_resource_ext",
 *   label = @Translation("Featured Resource - External"),
 *   description = @Translation("Renders a styled button link."),
 * )
 */
class ECShortCodesFeaturedResourceExt extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      'kicker' => NULL,
      'url' => NULL,
      'title' => NULL,
      'summary' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_shortcodes_featured_resource_ext',
      '#kicker' => $this->configuration['kicker'],
      '#url' => $this->configuration['url'],
      '#title' => $this->configuration['title'],
      '#summary' => $this->configuration['summary'],
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
    $form['url'] = [
      '#type' => 'url',
      '#title' => $this->t('Url'),
      '#default_value' => $this->configuration['url'],
      '#required' => TRUE,
      '#description' => $this->t('Enter a URL for an external resource.'),
    ];
    $form['title'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Text'),
      '#default_value' => $this->configuration['title'],
      '#required' => TRUE,
    ];
    $form['summary'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Summary'),
      '#default_value' => $this->configuration['summary'],
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
