<?php

namespace Drupal\ec_shortcodes\Plugin\EmbeddedContent;

use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;
use Drupal\embedded_content\EmbeddedContentInterface;
use Drupal\embedded_content\EmbeddedContentPluginBase;
use Drupal\multivalue_form_element\Element\MultiValue;

/**
 * Plugin iframes.
 *
 * @EmbeddedContent(
 *   id = "ec_shortcodes_do_dont_table",
 *   label = @Translation("Do/Don't Table"),
 *   description = @Translation("Renders a Do/Dont Table."),
 * )
 */
class ECShortcodesDoDontTable extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      'caption' => NULL,
      'rows' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_shortcodes_do_dont_table',
      '#caption' => $this->configuration['caption'],
      '#rows' => $this->configuration['rows'],
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    $form['caption'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Caption'),
      '#default_value' => $this->configuration['caption'],
      '#required' => TRUE,
    ];
    $form['rows'] = [
      '#type' => 'multivalue',
      '#title' => $this->t("Rows"),
      '#add_more_label' => $this->t('Add Row'),
      '#cardinality' => MultiValue::CARDINALITY_UNLIMITED,
      '#default_value' => $this->configuration['rows'],
      'do' => [
        '#type' => 'textarea',
        '#title' => $this->t('Do'),
        '#description' => $this->t('This will add text for the Do Colum'),
      ],
      'dont' => [
        '#type' => 'textarea',
        '#title' => $this->t("Don't"),
        '#description' => $this->t("This will add text for the Don't Colum"),
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