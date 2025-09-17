<?php

namespace Drupal\dg_autologout\Plugin\migrate\destination;

use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\migrate\Plugin\migrate\destination\Config;
use Drupal\migrate\Row;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Autologout Configuration Migration.
 *
 * @MigrateDestination(
 *   id = "config:dg_autologout",
 * )
 */
class ConfigAutologoutRoles extends Config {

  /**
   * The entity type manager service.
   *
   * @var \Drupal\Core\Entity\EntityTypeManagerInterface
   */
  protected $entityTypeManager;

  /**
   * Constructs a new ConfigAutologoutRoles object.
   *
   * @param \Drupal\Core\Entity\EntityTypeManagerInterface $entity_type_manager
   *   The entity type manager service.
   */
  public function __construct(EntityTypeManagerInterface $entity_type_manager) {
    $this->entityTypeManager = $entity_type_manager;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container, array $configuration, $plugin_id, $plugin_definition, $migration = NULL) {
    return new self(
      $container->get('entity_type.manager')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function import(Row $row, array $old_destination_id_values = []) {
    $dg_autologout_role = 'dg_autologout.role.';
    $roles = $this->entityTypeManager->getStorage('user_role')->loadMultiple();

    foreach ($roles as $role) {
      if (strtolower($row->getSourceProperty('role')) === strtolower($role->label())) {
        $dg_autologout_role = 'dg_autologout.role.' . $role->id();
        $this->config->setName($dg_autologout_role);
        $this->config->save();
        break;
      }
    }

    $entity_ids = parent::import($row, $old_destination_id_values);
    $entity_ids[0] = $dg_autologout_role;

    return $entity_ids;

  }

}
