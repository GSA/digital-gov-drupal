<?php

/**
 * @file
 * Theme preprocess functions.
 */

/**
 * Implements hook_preprocess_HOOK().
 */
function digital_gov_preprocess(&$variables) {
  $variables['theme_path'] = \Drupal::theme()->getActiveTheme()->getPath();
}
