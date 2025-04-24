<?php

namespace Drupal\ec_shortcodes\Plugin\EmbeddedContent;

use Drupal\Core\Entity\Element\EntityAutocomplete;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\Plugin\ContainerFactoryPluginInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;
use Drupal\embedded_content\EmbeddedContentInterface;
use Drupal\embedded_content\EmbeddedContentPluginBase;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Plugin iframes.
 *
 * @EmbeddedContent(
 *   id = "ec_shortcodes_featured_resource",
 *   label = @Translation("Featured Resource"),
 *   description = @Translation("Renders a styled button link."),
 * )
 */
final class ECShortcodesFeaturedResource extends EmbeddedContentPluginBase implements EmbeddedContentInterface, ContainerFactoryPluginInterface {

  use StringTranslationTrait;

  /**
   * The entity type manager.
   *
   * @var \Drupal\Core\Entity\EntityTypeManagerInterface
   */
  protected $entityTypeManager;

  /**
   * Constructs a ECShortcodesFeaturedResource.
   *
   * @param array $configuration
   *   A configuration array containing information about the plugin instance.
   * @param string $plugin_id
   *   The plugin_id for the plugin instance.
   * @param mixed $plugin_definition
   *   The plugin implementation definition.
   * @param \Drupal\Core\Entity\EntityTypeManagerInterface $entity_type_manager
   *   The entity type manager.
   */
  public function __construct(array $configuration, $plugin_id, $plugin_definition, EntityTypeManagerInterface $entity_type_manager) {
    parent::__construct($configuration, $plugin_id, $plugin_definition);

    $this->entityTypeManager = $entity_type_manager;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container, array $configuration, $plugin_id, $plugin_definition) {
    return new self(
      $configuration,
      $plugin_id,
      $plugin_definition,
      $container->get('entity_type.manager')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration() {
    return [
      'content_reference' => NULL,
      'kicker' => NULL,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    return [
      '#theme' => 'ec_shortcodes_featured_resource',
      '#content_reference' => $this->configuration['content_reference'],
      '#kicker' => $this->configuration['kicker']['value'],
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildConfigurationForm(array $form, FormStateInterface $form_state) {
    $node = NULL;
    if (!empty($this->configuration['content_reference'])) {
      $node = $this->entityTypeManager->getStorage('node')->load($this->configuration['content_reference']);
      $node = EntityAutocomplete::getEntityLabels([$node]);
    }

    $form['content_reference'] = [
      '#type' => 'entity_autocomplete',
      '#title' => $this->t('Content Reference'),
      '#target_type' => 'node',
      '#process_default_value' => FALSE,
      '#value_callback' => 'entity_autocomplete_value_callback',
      '#default_value' => $node,
      '#selection_handler' => 'default',
      '#required' => TRUE,
      '#selection_settings' => [
        'target_bundles' => [
          'authors', 'basic_page', 'community', 'event', 'guide_landing',
          'guides', 'landing_page', 'news', 'resources', 'topics',
        ],
      ],
    ];

    $form['kicker'] = [
      '#type' => 'text_format',
      '#title' => $this->t('Kicker'),
      '#default_value' => $this->configuration['kicker']['value'] ?? '',
      '#format' => 'single_inline_html',
      '#allowed_formats' => ['single_inline_html'],
      '#rows' => 1,
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
