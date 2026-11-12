<?php

/**
 * @file
 * Settings file for cloud.gov.
 */

$cf_application_data = json_decode(getenv('VCAP_APPLICATION') ?? '{}', TRUE);
$cf_service_data = json_decode(getenv('VCAP_SERVICES') ?? '{}', TRUE);

$application_environment = getenv('environment') ?? 'local';

$application_hostname = "https://" . $_SERVER['SERVER_NAME'];

$applicaiton_fqdn_regex = "^.+\.(app\.cloud\.gov|apps\.internal|digital\.gov)$";
$s3_proxy_path_cms = getenv('S3_PROXY_PATH_CMS') ?: '/s3/files';

$settings['tome_static_directory'] = dirname(DRUPAL_ROOT) . '/html';
$settings['config_sync_directory'] = dirname(DRUPAL_ROOT) . '/config/sync';
$settings['file_private_path'] = dirname(DRUPAL_ROOT) . '/private';

if (!empty(getenv("HASH_SALT"))) {
  $settings['hash_salt'] = hash('sha256', getenv("HASH_SALT"));
}

$settings['tome_static_path_exclude'] = [
  '/saml', '/saml/acs', '/saml/login', '/saml/logout', '/saml/metadata', '/saml/sls',
  '/jsonapi', '/jsonapi/deleted-nodes',
  '/es/saml', '/es/saml/acs', '/es/saml/login', '/es/saml/logout', '/es/saml/metadata', '/es/saml/sls',
  '/es/jsonapi', '/es/jsonapi/deleted-nodes',
];

// Default all splits to be off, then re-enable for the correct environments.
$config['config_split.config_split.develop']['status'] = FALSE;
$config['config_split.config_split.production']['status'] = FALSE;
$config['config_split.config_split.stage']['status'] = FALSE;
$config['config_split.config_split.test']['status'] = FALSE;
$config['config_split.config_split.local']['status'] = FALSE;
// Only for non-prod.
$config['config_split.config_split.non_production']['status'] = TRUE;
// Configuration for all remote environments.
$config['config_split.config_split.non_local']['status'] = TRUE;

if (!empty($cf_application_data['space_name']) &&
    $application_environment != 'local') {
  switch ($application_environment) {
    case "dev":
      $config['config_split.config_split.develop']['status'] = TRUE;
      $server_http_host = 'digital-gov-drupal-dev.app.cloud.gov';
      break;

    case "prod":
      $config['config_split.config_split.non_production']['status'] = FALSE;
      $config['config_split.config_split.production']['status'] = TRUE;
      $server_http_host = 'digital-gov-drupal-prod.app.cloud.gov';
      break;

    case "staging":
      $config['config_split.config_split.stage']['status'] = TRUE;
      $server_http_host = 'digital-gov-drupal-staging.app.cloud.gov';
      break;

    case "test":
      $config['config_split.config_split.test']['status'] = TRUE;
      $server_http_host = 'digital-gov-drupal-test.app.cloud.gov';
      break;

    default:
      throw new \Exception(sprintf('Invalid environment variable "environment" with value  of "%" given. Valid values are: dev, prod, staging, test.', $application_environment));
  }
}

foreach ($cf_service_data as $service_list) {
  foreach ($service_list as $service) {

    if (stristr($service['name'], 'mysql')) {
      $databases['default']['default'] = [
        'database' => $service['credentials']['db_name'],
        'username' => $service['credentials']['username'],
        'password' => $service['credentials']['password'],
        'prefix' => '',
        'host' => $service['credentials']['host'],
        'port' => $service['credentials']['port'],
        'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
        'driver' => 'mysql',
        'autoload' => 'core/modules/mysql/src/Driver/Database/mysql/',
      ];
      $rds_cert_path = "/home/vcap/app/govcloud-rds-ca.pem";
      if (is_readable($rds_cert_path)) {
        $databases['default']['default']['pdo'][PDO::MYSQL_ATTR_SSL_CA] = $rds_cert_path;
      }
    }
    // Route Drupal's own server-side HTTP through the egress proxy.
    //
    // Without this every Guzzle call fails once the space loses
    // public_networks_egress. The visible casualty is OpenID Connect: the browser
    // redirect to GSA Auth still works, but the code-for-token exchange is
    // server-to-server, so logins stop completing.
    //
    // Found by tag rather than service name, matching scripts/bootstrap.sh.
    elseif (!empty($service['tags']) && in_array('egress-proxy', $service['tags'], TRUE)) {
      if (!empty($service['credentials']['proxy_uri'])) {
        $settings['http_client_config']['proxy']['http'] = $service['credentials']['proxy_uri'];
        $settings['http_client_config']['proxy']['https'] = $service['credentials']['proxy_uri'];

        // Hosts that must NOT go through the proxy. Guzzle matches these as suffixes,
        // so a bucket-prefixed S3 hostname is covered by its endpoint.
        $http_proxy_bypass = [
          'localhost',
          '127.0.0.1',

          // Container-to-container routing.
          'apps.internal',

          // The site's own public hostnames. convert_text fetches
          // \Drupal::request()->getSchemeAndHttpHost() to resolve unrouted paths
          // (ConvertText.php:295, reachable from /admin/convert-text as well as from
          // migrations). The proxy is never the route from the app back to itself.
          $server_http_host ?? NULL,
          $_SERVER['SERVER_NAME'] ?? NULL,
        ];

        // S3 endpoints, read from VCAP_SERVICES so they cannot drift from what is
        // actually bound. Defensive rather than required: `aws s3 sync` is a separate
        // process reading http_proxy from the environment, which is deliberately not
        // exported, and s3fs (enabled via the non_local config split) uses the AWS
        // SDK's own Guzzle client, which does not read this setting either. This
        // covers any \Drupal::httpClient() call that targets S3 directly.
        foreach (($cf_service_data['s3'] ?? []) as $s3_service) {
          foreach (['fips_endpoint', 'endpoint'] as $s3_endpoint_key) {
            if (!empty($s3_service['credentials'][$s3_endpoint_key])) {
              $http_proxy_bypass[] = $s3_service['credentials'][$s3_endpoint_key];
            }
          }
        }

        $settings['http_client_config']['proxy']['no'] = array_values(array_unique(array_filter($http_proxy_bypass)));
      }
    }
    elseif (stristr($service['name'], 'secrets')) {
      if (!empty($service['credentials']['newrelic_key'])) {
        $settings['new_relic_rpm.api_key'] = $service['credentials']['newrelic_key'];
        $config['new_relic_rpm.settings']['api_key'] = $service['credentials']['newrelic_key'];
      } elseif (!empty(getenv('NEWRELIC_KEY'))) {
        $settings['new_relic_rpm.api_key'] = getenv('NEWRELIC_KEY');
        $config['new_relic_rpm.settings']['api_key'] = getenv('NEWRELIC_KEY');
      }

      // Set the key required to make successful SSO calls with GSA Auth.
      if (!empty($service['credentials']['gsa_auth_key'])) {
         $config['openid_connect.client.gsa_auth']['settings']['client_secret'] = $service['credentials']['gsa_auth_key'];
      }

      if (!empty($service['credentials']['cron_key'])) {
        $settings['cron_key'] = hash('sha256', $service['credentials']['cron_key']);
      }

      if (!empty($service['credentials']['hash_salt']) && empty($settings['hash_salt'])) {
        $settings['hash_salt'] = hash('sha256', $service['credentials']['hash_salt']);
      }

    }
    elseif (stristr($service['name'], 'storage')) {
      $settings['s3fs.access_key'] = $service['credentials']['access_key_id'];
      $settings['s3fs.secret_key'] = $service['credentials']['secret_access_key'];
      $config['s3fs.settings']['bucket'] = $service['credentials']['bucket'];
      $config['s3fs.settings']['region'] = $service['credentials']['region'];

      $config['s3fs.settings']['disable_cert_verify'] = FALSE;

      $config['s3fs.settings']['root_folder'] = 'cms';

      $config['s3fs.settings']['public_folder'] = 'public';
      $config['s3fs.settings']['private_folder'] = 'private';

      $config['s3fs.settings']['use_cname'] = TRUE;
      $config['s3fs.settings']['domain'] = $server_http_host . $s3_proxy_path_cms;
      $config['s3fs.settings']['domain_root'] = 'public';

      $config['s3fs.settings']['use_customhost'] = TRUE;
      $config['s3fs.settings']['hostname'] = $service['credentials']['fips_endpoint'];
      $config['s3fs.settings']['use-path-style-endpoint'] = FALSE;

      $config['s3fs.settings']['use_cssjs_host'] = FALSE;
      $config['s3fs.settings']['cssjs_host'] = '';

      $config['s3fs.settings']['use_https'] = TRUE;
      $settings['s3fs.upload_as_private'] = FALSE;
      $settings['s3fs.use_s3_for_public'] = TRUE;
      $settings['s3fs.use_s3_for_private'] = TRUE;
    }
    elseif (
      !empty($service['tags']) &&
      in_array('cache-service', $service['tags'], TRUE)
    ) {
      $redis_host = $service['credentials']['hostname'] ?? $service['credentials']['host'] ?? NULL;
      $redis_port = $service['credentials']['port'] ?? NULL;
      $redis_password = $service['credentials']['password'] ?? NULL;

      if ($redis_host && $redis_port && $redis_password) {
        require_once 'settings.redis.php';
        if (function_exists('_settings_redis')) {
          // Cloud.gov ElastiCache requires in-transit TLS. The redis module
          // has no scheme/ssl settings; PhpRedis negotiates TLS only when the
          // host carries a tls:// prefix.
          _settings_redis($settings, 'tls://' . $redis_host, (string) $redis_port);
          $settings['redis.connection']['password'] = $redis_password;
          $settings['redis.connection']['persistent'] = TRUE;
        }
      }
    }
  }
}

$settings['php_storage']['twig']['directory'] = '../storage/php';
$settings['cache']['bins']['data'] = 'cache.backend.php';
$settings['trusted_host_patterns'][] = $applicaiton_fqdn_regex;

// SSO - SAML Auth Config.
// $config['samlauth.authentication']['idp_certs'][] = getenv('sso_x509_cert');
// @todo DC - Move the following to config split for respective environments.
// switch ($application_environment) {
//   case "dev":
//     $config['config_split.config_split.non_production']['status'] = TRUE;
//     $config['samlauth.authentication']['sp_entity_id'] = 'digital-gov-drupal-dev.app.cloud.gov';
//     $config['samlauth.authentication']['idp_single_sign_on_service'] = 'https://auth-preprod.gsa.gov';
//     break;

//   case "prod":
//     $config['config_split.config_split.production']['status'] = TRUE;
//     $config['samlauth.authentication']['sp_entity_id'] = 'digital-gov-drupal-prod.app.cloud.gov';
//     $config['samlauth.authentication']['idp_single_sign_on_service'] = 'https://secureauth.gsa.gov';
//     break;

//   case "stage":
//     $config['config_split.config_split.non_production']['status'] = TRUE;
//     $config['samlauth.authentication']['sp_entity_id'] = 'digital-gov-drupal-staging.app.cloud.gov';
//     $config['samlauth.authentication']['idp_single_sign_on_service'] = 'https://auth-preprod.gsa.gov';
//     break;

//   case "test":
//     $config['config_split.config_split.non_production']['status'] = TRUE;
//     $config['samlauth.authentication']['sp_entity_id'] = 'digital-gov-drupal-test.app.cloud.gov';
//     $config['samlauth.authentication']['idp_single_sign_on_service'] = 'https://auth-preprod.gsa.gov';
//     break;
// }
