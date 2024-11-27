<?php

/**
 * @file
 * Configure settings.php for lando.
 */
$lando_info = json_decode(getenv('LANDO_INFO'));

// Disable all splits not meant for local.
$config['config_split.config_split.non_local']['status'] = FALSE;
$config['config_split.config_split.develop']['status'] = FALSE;
$config['config_split.config_split.stage']['status'] = FALSE;
$config['config_split.config_split.production']['status'] = FALSE;
// Enable local splits.
$config['config_split.config_split.local']['status'] = TRUE;

if (isset($lando_info->database)) {
  $databases['default']['default'] = [
    'database' => $lando_info->database->creds->database,
    'username' => $lando_info->database->creds->user,
    'password' => $lando_info->database->creds->password,
    'prefix' => '',
    'host' => $lando_info->database->internal_connection->host,
    'port' => $lando_info->database->internal_connection->port,
  ];

  // Lando DB connection.
  switch ($lando_info->database->type) {
    case 'mysql';
    case 'drupal-mysql';
    case 'mariadb':
    case 'drupal-mariadb':
      $databases['default']['default'] += [
        'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
        'driver' => 'mysql',
      ];
      break;

    case 'postgres';
    case 'drupal-postgres';
      $databases['default']['default'] += [
        'namespace' => 'Drupal\\pgsql\\Driver\\Database\\pgsql',
        'driver' => 'pgsql',
      ];
      break;

    default:
      throw new \Exception('The Database type "' . $lando_info->database->type . "' is not automatically able to be configured.");
  }
}

if (isset($lando_info->cache->type)) {
  switch ($lando_info->cache->type) {
    case 'redis':
      require 'settings.redis.php';
      if (function_exists('_settings_redis')) {
        _settings_redis(
          $settings,
          $lando_info->cache->internal_connection->host,
          $lando_info->cache->internal_connection->port
        );
      }
      break;

    case 'memcached':
      require 'settings.memcache.php';
      if (function_exists('_settings_memcache')) {
        $memcache_host = implode(':', (array)$lando_info->cache->internal_connection);
        _settings_memcache($settings, $memcache_host);
      }
      break;

    default:
      throw new \Exception('The Cache type "' . $lando_info->cache->type . "' is not automatically able to be configured.");

  }
}

if (isset($lando_info->search->type)) {
  switch ($lando_info->search->type) {
    case 'solr':
      $config['search_api.server.default_solr_server']['backend_config']['connector_config'] = [
        'core' => $lando_info->search->core,
        'path' => '',
        'host' => $lando_info->search->internal_connection->host,
        'port' => $lando_info->search->internal_connection->port,
      ];
      break;

    case 'elasticsearch':
      $config['search_api.server.default_elasticsearch_server']['backend_config']['connector_config']['url'] = sprintf(
        'http://%s:%d',
        $lando_info->search->internal_connection->host,
        $lando_info->search->internal_connection->port
      );
      break;

    default:
      throw new \Exception('The Search type "' . $lando_info->search->type . "' is not automatically able to be configured.");

  }
}
