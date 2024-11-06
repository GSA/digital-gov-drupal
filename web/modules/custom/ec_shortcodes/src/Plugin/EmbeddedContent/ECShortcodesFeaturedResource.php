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
 *   id = "ec_shortcodes_featured_resource",
 *   label = @Translation("Featured Resource"),
 *   description = @Translation("Renders a styled button link."),
 * )
 */
class ECShortcodesFeaturedResource extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      // 'kicker' => NULL,
      // 'url' => NULL,
      // 'text' => NULL,
      // 'summary' => NULL,
      'content_reference' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_shortcodes_featured_resource',
      // '#kicker' => $this->configuration['kicker'],
      // '#url' => $this->configuration['url'],
      // '#title' => $this->configuration['text'],
      // '#summary' => $this->configuration['summary'],
      '#content_reference' => $this->configuration['content_reference'],

    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    // $form['kicker'] = [
    //   '#type' => 'textfield',
    //   '#title' => $this->t('Kicker'),
    //   '#default_value' => $this->configuration['text'],
    //   '#required' => TRUE,
    // ];
    // $form['url'] = [
    //   '#type' => 'url',
    //   '#title' => $this->t('Url'),
    //   '#default_value' => $this->configuration['url'],
    //   '#required' => TRUE,
    // ];
    // $form['title'] = [
    //   '#type' => 'textfield',
    //   '#title' => $this->t('Text'),
    //   '#default_value' => $this->configuration['text'],
    //   '#required' => TRUE,
    // ];
    // $form['summary'] = [
    //   '#type' => 'textfield',
    //   '#title' => $this->t('Summary'),
    //   '#default_value' => $this->configuration['text'],
    //   '#required' => TRUE,
    // ];
$form['content_reference'] = [
      '#type' => 'entity_autocomplete',
      '#title' => $this->t('Content Reference'),
      '#target_type' => 'node',
      '#process_default_value' => FALSE,
      '#value_callback' => 'entity_autocomplete_value_callback',
      '#default_value' => $this->configuration['content_reference'],
      '#selection_handler' => 'default',
      '#required' => TRUE,
      '#selection_settings' => [
        'target_bundles' => ['authors', 'basic_page', 'community', 'event', 'gide', 'news','resources','services', 'topics'],
      ],
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
