<?php

namespace Drupal\ec_shortcodes_button\Plugin\EmbeddedContent;

use Drupal\embedded_content\EmbeddedContentInterface;
use Drupal\embedded_content\EmbeddedContentPluginBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;

/**
 * Plugin iframes.
 *
 * @EmbeddedContent(
 *   id = "ec_shortcodes_button",
 *   label = @Translation("Button"),
 *   description = @Translation("Renders a button."),
 * )
 */
class ECShortcodesButton extends EmbeddedContentPluginBase implements EmbeddedContentInterface
{

    use StringTranslationTrait;

    /**
     * {@inheritdoc}
     */
    public function defaultConfiguration()
    {
        return [
        'url' => NULL,
        'text' => NULL,
        ];
    }

    /**
     * {@inheritdoc}
     */
    public function build(): array
    {
        return [
        '#theme' => 'ec_shortcodes_button',
        '#url' => $this->configuration['url'],
        '#text' => $this->configuration['text'],
        ];
    }

    /**
     * {@inheritdoc}
     */
    public function buildConfigurationForm(array $form, FormStateInterface $form_state)
    {
        $form['url'] = [
        '#type' => 'url',
        '#title' => $this->t('Url'),
        '#default_value' => $this->configuration['url'],
        '#required' => TRUE,
        ];
        $form['text'] = [
        '#type' => 'textfield',
        '#title' => $this->t('text'),
        '#default_value' => $this->configuration['text'],
        '#required' => TRUE,
        ];
        return $form;
    }

    /**
     * {@inheritDoc}
     */
    public function isInline(): bool
    {
        return FALSE;
    }

}
