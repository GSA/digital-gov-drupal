<?php

namespace Drupal\dg_autologout\Plugin\migrate\source\d6;

use Drupal\dg_autologout\Plugin\migrate\source\AutologoutRoles as AutologoutRolesGeneral;

/**
 * Drupal 6 Autologout source from database.
 *
 * @MigrateSource(
 *   id = "d6_dg_autologout_roles",
 *   source_module = "dg_autologout",
 * )
 */
class AutologoutRoles extends AutologoutRolesGeneral {}
