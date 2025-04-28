<?php

declare(strict_types=1);

namespace Drupal\convert_text\Form;

use Symfony\Component\DependencyInjection\ContainerInterface;
use Drupal\convert_text\ShortcodeToEquiv;
use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\convert_text\ConvertText;

/**
 * Provides a Convert Text form.
 */
final class ConvertTextForm extends FormBase {

  /**
   * ConvertText service.
   *
   * @var \Drupal\convert_text\ConvertText
   */
  protected ConvertText $convertText;

  /**
   * ShortcodeToEquiv service.
   *
   * @var \Drupal\convert_text\ShortcodeToEquiv
   */
  protected ShortcodeToEquiv $shortcodeToEquiv;

  /**
   * Create the ConvertTextForm class.
   *
   * @param \Drupal\convert_text\ShortcodeToEquiv $shortcode_to_equiv
   *   The shortcode to equivalent service.
   */
  public function __construct(ShortcodeToEquiv $shortcode_to_equiv) {
    $this->shortcodeToEquiv = $shortcode_to_equiv;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('convert_text.shortcode_to_equiv')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId(): string {
    return 'convert_text_convert_text';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state): array {

    if ($converted_text = $form_state->getValue('converted_text')) {
      $form['converted_text'] = [
        '#type' => 'textarea',
        '#title' => $this->t('Converted Text'),
        '#default_value' => $converted_text,
        '#disabled' => TRUE,
      ];

      switch ($form_state->getValue('dest')) {
        case 'html':
          $form['html_filter'] = [
            '#markup' => '<h5>HTML Filter</h5>' . check_markup($converted_text, 'html'),
          ];
          $form['multiline_filter'] = [
            '#markup' => '<h5>Multiline HTML Filter</h5>' . check_markup($converted_text, 'multiline_inline_html'),
          ];
          $form['single_inline_filter'] = [
            '#markup' => '<h5>Single Inline Filter</h5>' . check_markup($converted_text, 'single_inline_html'),
          ];
          break;

        case 'plain_text':
          $form['Plain text'] = [
            '#markup' => '<h5>Plain text</h5>' . check_markup($converted_text, 'plain_text'),
          ];
          break;
      }
    }

    $form['source_text'] = [
      '#type' => 'textarea',
      '#title' => $this->t('Source Text'),
      '#required' => TRUE,
    ];
    $form['dest'] = [
      '#type' => 'radios',
      '#title' => $this->t('Destination'),
      '#options' => [
        'plain_text' => $this->t('Fields like title. This will decode the HTML entities like &amp;#8221 into ” (right double quotation mark).'),
        'html' => $this->t('Fields like body that summary or body that will contain HTML and Markdown'),
      ],
      '#required' => TRUE,
    ];
    $form['actions'] = [
      '#type' => 'actions',
      'submit' => [
        '#type' => 'submit',
        '#value' => $this->t('Convert'),
      ],
      'reset' => [
        '#type' => 'submit',
        '#value' => $this->t('Reset'),
      ],
    ];

    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state): void {
    if ((string) $form_state->getValue('op') === 'Reset') {
      return;
    }
    $source_text = $form_state->getValue('source_text');

    // Convert shortcodes to their equivalent Drupal form.
    $source_text = $this->shortcodeToEquiv->convert('/just/a/test', $source_text);

    switch ($form_state->getValue('dest')) {
      case 'plain_text':
        $decoded_entities = ConvertText::plainText($source_text);
        $decoded_entities = ConvertText::plainTextAfterMigrate($decoded_entities);
        $form_state->setValue('converted_text', $decoded_entities);
        $this->messenger()->addStatus($this->t('Copy the converted text field into a plain text field.'));
        break;

      case 'html':
        $html = ConvertText::htmlText($source_text);
        $html = ConvertText::htmlTextAfterMigrate($html);
        $form_state->setValue('converted_text', $html);
        $this->messenger()->addStatus($this->t('Copy the converted text field into an HTML field. If using a WYSIWYG, click "source" first.'));
        break;

    }

    // Allows the form state values to persist after submission so form is pre-
    // filled with same options.
    $form_state->setRebuild();
  }

}
