<?php

namespace Drupal\ec_shortcodes\Plugin\EmbeddedContent;

use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\Plugin\ContainerFactoryPluginInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;
use Drupal\embedded_content\EmbeddedContentInterface;
use Drupal\embedded_content\EmbeddedContentPluginBase;
use Drupal\path_alias\AliasManagerInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Plugin iframes.
 *
 * @EmbeddedContent(
 *   id = "ec_shortcodes_card_policy",
 *   label = @Translation("Card Policy"),
 *   description = @Translation("Renders an accordion with policy."),
 * )
 */
class ECShortcodesCardPolicy extends EmbeddedContentPluginBase implements EmbeddedContentInterface, ContainerFactoryPluginInterface {

  use StringTranslationTrait;

  public function __construct(private AliasManagerInterface $aliasManager, array $configuration, string $plugin_id, array $plugin_definition) {
    parent::__construct($configuration, $plugin_id, $plugin_definition);
  }

  /**
   * Dependency Injection via Container.
   *
   * @param \Symfony\Component\DependencyInjection\ContainerInterface $container
   *   Services container.
   * @param array $configuration
   *   Plugin configuration.
   * @param string $plugin_id
   *   Plugin string identifier.
   * @param array $plugin_definition
   *   Plugin definition.
   */
  public static function create(ContainerInterface $container, array $configuration, $plugin_id, $plugin_definition): self {
    return new self($container->get('path_alias.manager'), $configuration, $plugin_id, $plugin_definition);
  }

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration(): array {
    return [
      'kicker' => NULL,
      'card_title' => NULL,
      'src' => NULL,
      'text' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    $url = $this->configuration['url'];
    // A URL starting with two slashes is a protocol relative external link.
    if (str_starts_with($url, '/') && !str_starts_with($url, '//')) {
      $url = $this->aliasManager->getAliasByPath($url);
    }

    return [
      '#theme' => 'ec_shortcodes_card_policy',
      '#kicker' => $this->configuration['kicker'],
      '#card_title' => $this->configuration['card_title'],
      '#url' => $url,
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
    $form['card_title'] = [
      '#type' => 'text_format',
      '#title' => $this->t('Title'),
      '#default_value' => $this->configuration['card_title']['value'] ?? '',
      '#format' => 'single_inline_html',
      '#allowed_formats' => ['single_inline_html'],
      '#rows' => 1,
      '#required' => TRUE,
    ];
    $form['url'] = [
      '#title' => $this->t('URL'),
      '#description' => $this->t('Used in link at end of card. Enter a title to find an internal page or enter an external URL.'),
      '#default_value' => $this->configuration['url'] ?? '',
      '#required' => TRUE,
      '#type' => 'linkit',
      '#autocomplete_route_name' => 'linkit.autocomplete',
      '#autocomplete_route_parameters' => [
        'linkit_profile_id' => 'default',
      ],
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
