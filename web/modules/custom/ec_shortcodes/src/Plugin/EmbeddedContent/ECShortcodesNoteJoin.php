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
 *   id = "ec_shortcodes_note_join",
 *   label = @Translation("Note - Join"),
 *   description = @Translation("Renders Note - Join component."),
 * )
 */
class ECShortcodesNoteJoin extends EmbeddedContentPluginBase implements EmbeddedContentInterface {

  use StringTranslationTrait;

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      // 'heading' => NULL,
      // 'type' => NULL,
      'text' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_shortcodes_note_join',
      // '#heading' => $this->configuration['heading'],
      // '#type' => $this->configuration['type'],
      '#text' => $this->configuration['text'],
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    // $form['heading'] = [
    //   '#type' => 'textfield',
    //   '#title' => $this->t('Note Heading'),
    //   '#default_value' => $this->configuration['heading'],
    // ];
    // $form['type'] = [
    //   '#type' => 'select',
    //   '#title' => $this->t('Note Type'),
    //   '#options' => [
    //     'activity' => $this->t('Activity'),
    //     'action' => $this->t('Action'),
    //     'alert' => $this->t('Alert'),
    //     'comment' => $this->t('Comment'),
    //     'video' => $this->t('Video'),
    //     'join' => $this->t('Join'),
    //     'note' => $this->t('Note'),
    //     'disclaimer' => $this->t('Disclaimer'),
    //   ],
    //   '#default_value' => $this->configuration['type'],
    //   '#required' => TRUE,
    // ];
    $form['text'] = [
      '#type' => 'text_format',
      '#title' => $this->t('Note Text'),
      '#format' => $this->configuration['text']['format'] ?? 'html',
      '#allowed_formats' => ['html'],
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
