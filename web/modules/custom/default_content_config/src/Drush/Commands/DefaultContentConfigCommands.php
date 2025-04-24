<?php

namespace Drupal\default_content_config\Drush\Commands;

use Consolidation\OutputFormatters\StructuredData\RowsOfFields;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drush\Attributes as CLI;
use Drush\Commands\DrushCommands;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Provides Drush commands for the Default Content Config module.
 */
final class DefaultContentConfigCommands extends DrushCommands {

  /**
   * Constructs a DefaultContentConfigCommands object.
   */
  public function __construct(
    private readonly EntityTypeManagerInterface $entityTypeManager,
  ) {
    parent::__construct();
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('entity_type.manager'),
    );
  }

  /**
   * Remove all sample content before a migration that brings in real content.
   */
  #[CLI\Command(name: 'default_content_config:remove-content-before-migration', aliases: ['rcbm'])]
  #[CLI\Usage(name: 'default_content_config:remove-content-before-migration', description: 'Remove all sample content before a migration that brings in real content.')]
  public function removeContentBeforeMigration(): RowsOfFields {
    $entity_types = [
      'file',
      'media',
      'node',
    ];
    $count = 0;
    foreach ($entity_types as $entity_type) {
      $storage = $this->entityTypeManager->getStorage($entity_type);
      $query = $storage->getQuery()->accessCheck(FALSE);
      $description = 'all';
      switch ($entity_type) {
        case 'node':
          $query->condition('type', ['landing_page'], 'NOT IN');
          $description = 'all except landing page types.';
          break;

        case 'user':
          $query->condition('uid', [0, 1], 'NOT IN');
          $description = 'all except admin and anon.';
          break;

      }
      $ids = $query->execute();
      foreach ($storage->loadMultiple($ids) as $entity) {
        $entity->delete();
        $count++;
      }
      $rows[] = [
        'entity type' => $entity_type,
        'removed' => $description,
        'removed count' => count($ids),
      ];
    }
    $this->logger()
      ->success(dt('Removed {count} pieces of sample content of types {types}.', [
        'count' => $count,
        'types' => implode(', ', $entity_types),
      ]));
    return new RowsOfFields($rows);
  }

}
