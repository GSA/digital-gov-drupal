<?php

namespace Drupal\dg_autologout\Plugin\migrate\destination;

use Drupal\migrate\Plugin\migrate\destination\Config;
use Drupal\migrate\Row;

/**
 * Autologout Configuration Migration.
 *
 * @MigrateDestination(
 *   id = "config:dg_autologout",
 * )
 */
class ConfigAutologoutRoles extends Config {

  /**
   * {@inheritdoc}
   */
  public function import(Row $row, array $old_destination_id_values = []) {
    $dg_autologout_role = 'dg_autologout.role.';
    $roles = \Drupal::entityTypeManager()->getStorage('user_role')->loadMultiple();
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
