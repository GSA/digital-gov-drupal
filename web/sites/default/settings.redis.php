<?php

use Drupal\Core\Installer\InstallerKernel;

// PhpRedis must win over Predis: the redis module's stock Predis client drops
// the scheme and so cannot do TLS, which Cloud.gov ElastiCache requires
// (fixable with the patch from drupal.org issue #3004561, which this project
// does not carry). PhpRedis supports TLS through a tls:// host prefix.
$redis_interface = extension_loaded('redis') ? 'PhpRedis' : (class_exists('Predis\Client') ? 'Predis' : NULL);

if ((
  !InstallerKernel::installationAttempted() &&
  $redis_interface &&
  class_exists('Drupal\redis\ClientFactory')
)) {
  function _settings_redis(array &$settings, string $host, string $port): void {
    $settings['redis.connection']['host'] = $host;
    $settings['redis.connection']['port'] = $port;
  }

  $settings['redis.connection']['interface'] = $redis_interface;
  # Use for all bins otherwise specified.
  $settings['cache']['default'] = 'cache.backend.redis';

  // Optional settings:

  // Apply changes to the container configuration to better leverage Redis.
  // This includes using Redis for the lock and flood control systems, as well
  // as the cache tag checksum. Alternatively, copy the contents of that file
  // to your project-specific services.yml file, modify as appropriate, and
  // remove this line.
  $settings['container_yamls'][] = 'modules/contrib/redis/example.services.yml';

  // Allow the services to work before the Redis module itself is enabled.
  $settings['container_yamls'][] = 'modules/contrib/redis/redis.services.yml';

  // Manually add the classloader path, this is required for the container cache bin definition below
  // and allows to use it without the redis module being enabled.
  $class_loader->addPsr4('Drupal\\redis\\', 'modules/contrib/redis/src');

  require 'settings.redis.container.php';
}





