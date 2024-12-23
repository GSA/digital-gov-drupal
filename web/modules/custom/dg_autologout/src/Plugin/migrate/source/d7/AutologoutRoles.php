<?php

namespace Drupal\dg_autologout\Plugin\migrate\source\d7;

use Drupal\dg_autologout\Plugin\migrate\source\AutologoutRoles as AutologoutRolesGeneral;

/**
 * Drupal 7 Autologout source from database.
 *
 * @MigrateSource(
 *   id = "d7_dg_autologout_roles",
 *   source_module = "dg_autologout",
 * )
 */
class AutologoutRoles extends AutologoutRolesGeneral {}
