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

$settings['hash_salt'] = getenv("HASH_SALT");

$settings['tome_static_path_exclude'] = [
  '/saml', '/saml/acs', '/saml/login', '/saml/logout', '/saml/metadata', '/saml/sls',
  '/jsonapi', '/jsonapi/deleted-nodes',
  '/es/saml', '/es/saml/acs', '/es/saml/login', '/es/saml/logout', '/es/saml/metadata', '/es/saml/sls',
  '/es/jsonapi', '/es/jsonapi/deleted-nodes',
];

$is_cloudgov = FALSE;

if (!empty($cf_application_data['space_name']) &&
    $application_environment != 'local') {
  switch ($application_environment) {
    case "dev":
      $is_cloudgov = TRUE;
      $server_http_host = 'digital-gov-drupal-dev.app.cloud.gov';
      break;

    case "prod":
      $is_cloudgov = TRUE;
      $server_http_host = 'digital-gov-drupal-prod.app.cloud.gov';
      break;

    case "stage":
      $is_cloudgov = TRUE;
      $server_http_host = 'digital-gov-drupal-stage.app.cloud.gov';
      break;

    case "test":
      $is_cloudgov = TRUE;
      $server_http_host = 'digital-gov-drupal-test.app.cloud.gov';
      break;
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
    }
    elseif (stristr($service['name'], 'secrets')) {
      if (!empty($service['credentials']['newrelic_key'])) {
        $settings['new_relic_rpm.api_key'] = $service['credentials']['newrelic_key'];
        $config['new_relic_rpm.settings']['api_key'] = $service['credentials']['newrelic_key'];
      }
      $settings['cron_key'] = hash('sha256', $service['credentials']['cron_key']);
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
  }
}

$settings['php_storage']['twig']['directory'] = '../storage/php';
$settings['cache']['bins']['data'] = 'cache.backend.php';
$settings['state_cache'] = TRUE;
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
//     $config['samlauth.authentication']['sp_entity_id'] = 'digital-gov-drupal-stage.app.cloud.gov';
//     $config['samlauth.authentication']['idp_single_sign_on_service'] = 'https://auth-preprod.gsa.gov';
//     break;

//   case "test":
//     $config['config_split.config_split.non_production']['status'] = TRUE;
//     $config['samlauth.authentication']['sp_entity_id'] = 'digital-gov-drupal-test.app.cloud.gov';
//     $config['samlauth.authentication']['idp_single_sign_on_service'] = 'https://auth-preprod.gsa.gov';
//     break;
// }
