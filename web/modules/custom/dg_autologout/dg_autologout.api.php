<?php

/**
 * @file
 * Describe hooks provided by the dg_autologout module.
 */

/**
 * Prevent dg_autologout logging a user out.
 *
 * This allows other modules to indicate that a page should not be included
 * in the dg_autologout checks. This works in the same way as not ticking the
 * enforce on admin pages option for
 * dg_autologout which stops a user being logged
 * out of admin pages.
 *
 * @return bool
 *   Return TRUE if you do not want the user to be logged out.
 *   Return FALSE (or nothing) if you want to leave the dg_autologout
 *   process alone.
 */
function hook_dg_autologout_prevent() {
  // Don't include dg_autologout JS checks on ajax callbacks.
  $path_args = explode('/', current_path());
  $blacklist = [
    'ajax',
    'dg_autologout_ajax_logout',
    'dg_autologout_ajax_set_last',
  ];

  if (in_array($path_args[0], $blacklist)) {
    return TRUE;
  }
}

/**
 * Keep a login alive whilst the user is on a particular page.
 *
 * @return bool
 *   By returning TRUE from this function the JS which talks to dg_autologout
 *   module is included in the current page request and periodically dials back
 *   to the server to keep the login alive.
 *   Return FALSE (or nothing) to just use the standard behaviour.
 */
function hook_dg_autologout_refresh_only() {
  // Check to see if an open admin page will keep login alive.
  if (\Drupal::service('router.admin_context')->isAdminRoute(routeMatch()->getRouteObject()) && !\Drupal::config('dg_autologout.settings')->get('enforce_admin')) {
    return TRUE;
  }
}

/**
 * React right after user has been logged out via dg_autologout.
 *
 * This hook fires only when user is logged out via dg_autologout, not when the
 * user logs themselves out. This is fired after the session has been destroyed
 * and the active user has been set to anonymous.
 */
function hook_dg_autologout_user_logout() {
}
