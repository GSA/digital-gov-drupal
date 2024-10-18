<?php

namespace Drupal\ec_uswds\Plugin\EmbeddedContent;

use Drupal\embedded_content\EmbeddedContentInterface;
use Drupal\embedded_content\EmbeddedContentPluginBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;

/**
 * Plugin iframes.
 *
 * @EmbeddedContent(
 *   id = "ec_usaalert",
 *   label = @Translation("USWDS: alert"),
 *   description = @Translation("Renders a inline alert."),
 * )
 */
class ECUsaAlert extends EmbeddedContentPluginBase implements EmbeddedContentInterface
{

    use StringTranslationTrait;

    /**
     * {@inheritdoc}
     */
    public function defaultConfiguration()
    {
        return [
        'heading' => null,
        'type' => null,
        'text' => null,
        ];
    }

    /**
     * {@inheritdoc}
     */
    public function build(): array
    {
        return [
        '#theme' => 'ec_usaalert',
        '#heading' => $this->configuration['heading'],
        '#type' => $this->configuration['type'],
        '#text' => $this->configuration['text'],
        ];
    }

    /**
     * {@inheritdoc}
     */
    public function buildConfigurationForm(array $form, FormStateInterface $form_state)
    {
        $form['heading'] = [
        '#type' => 'textfield',
        '#title' => $this->t('Alert Heading'),
        '#default_value' => $this->configuration['heading'],
        ];
        $form['type'] = [
        '#type' => 'select',
        '#title' => $this->t('Alert type'),
        '#options' => [
        'info' => $this->t('Info'),
        'warning' => $this->t('Warning'),
        ],
        '#default_value' => $this->configuration['type'],
        '#required' => true,
        ];
        $form['text'] = [
        '#type' => 'text_format',
        '#title' => $this->t('Alert text'),
        '#format' => $this->configuration['text']['format'] ?? 'html',
        '#allowed_formats' => ['html'],
        '#default_value' => $this->configuration['text']['value'] ?? '',
        '#required' => true,
        ];
        return $form;
    }

    /**
     * {@inheritDoc}
     */
    public function isInline(): bool
    {
        return false;
    }

}
