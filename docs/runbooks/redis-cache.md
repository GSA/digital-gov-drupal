# Redis cache service

The Drupal application uses Valkey only when a bound Cloud.gov service has the
`cache-service` tag. Without that binding, it uses the configured default cache
backend. Local Lando development continues to use Memcached.

Cloud.gov ElastiCache requires TLS for every connection. This project connects
with the PhpRedis extension (enabled in
`.bp-config/php/php.ini.d/extensions.ini`), which negotiates TLS from the
`tls://` host prefix that `settings.cloudgov.php` applies. PhpRedis needs no
patch for that.

Predis can also reach Cloud.gov ElastiCache, but only with the patch from
[#3004561](https://www.drupal.org/project/redis/issues/3004561); the redis
module's stock Predis client drops the scheme. USAGov carries that patch and
found Predis to be the faster of the two, so a PhpRedis/Predis comparison here
is worth a follow-up ticket.

## Deploy

The `terraform/infra` configuration provisions a
`${PROJECT}-cache-${CF_SPACE}` `aws-elasticache-redis` service on the
`redis-3node-large` plan in each workspace. It explicitly selects the Valkey
8.2 engine and tags the service so Drupal can discover it through
`VCAP_SERVICES`.

The broker reads the engine version from a snake_case `engine_version`
parameter and silently falls back to its Redis 7.1 plan default on any other
key, which AWS rejects for the Valkey engine ("Cannot find version 7.1 for
valkey"). The Cloud.gov docs show a camelCase `engineVersion` parameter that
the deployed broker does not parse; Terraform sends both keys.

If a previous provision attempt failed, delete the failed instance before
re-applying, or the broker can refuse the retry:

```sh
cf delete-service "${PROJECT}-cache-${CF_SPACE}"
```

Before deploying, confirm the target space has the
`trusted_local_networks_egress` running security group. Cloud.gov requires this
group for applications to reach brokered ElastiCache services. This repository's
OpenTofu ASG binding is disabled because of a Cloud Foundry provider limitation,
so a platform operator must add the group when it is absent.

The normal build-and-deploy workflow applies infrastructure before deploying
Drupal. `cloud-gov-deploy.sh` replaces the `# CACHE_SERVICE_BINDING`
placeholder in `manifest.yml` only when the cache service exists and its last
operation succeeded, so the application deploys with or without the service.
The infrastructure step waits for ElastiCache provisioning to finish before the
Drupal deploy starts, so the binding lands on that same deploy rather than
needing a second run. A first-time provision took about three minutes.

## Verify

Do not use `cf env` for verification: it prints every bound credential
(database, S3, and cache passwords) to the terminal or CI log.

Check the service and its binding without exposing credentials:

```sh
cf service "${PROJECT}-cache-${CF_SPACE}"
```

The output should show the last operation succeeded and list
`${PROJECT}-drupal-${CF_SPACE}` under bound apps.

### From the CMS

The `redis` module is installed, so an admin user can check the connection from
the CMS at `/admin/reports/redis` (also linked as "Redis" under Reports). The
page reports the module's configuration and cache activity, and reports
`Not connected.` when no cache service is bound. Use this in spaces where SSH
is disabled, such as production.

### Over SSH

Where SSH is available, confirm the cache backend Drupal actually resolved:

```sh
./scripts/pipeline/cloud-gov-remote-command.sh "${PROJECT}-drupal-${CF_SPACE}" \
  "drush php:eval \"print get_class(\Drupal::cache('default'));\"" show
```

This prints `Drupal\redis\Cache\PhpRedis` when the cache service is in use and
`Drupal\Core\Cache\DatabaseBackend` when Drupal has fallen back to the
database.

If the script fails with `permission denied`, the SSH proxy rejected the
connection, usually because SSH is off at the space or the app level. Check
both:

```sh
cf space-ssh-allowed "${CF_SPACE}"
cf ssh-enabled "${PROJECT}-drupal-${CF_SPACE}"
```

Turning either on (`cf allow-space-ssh`, `cf enable-ssh`) requires a restart of
the app before the proxy accepts connections. Where SSH is off deliberately,
use the CMS report above rather than enabling it.

## Measure static generation

Capture a comparable dev baseline from the `Build Static Site` workflow before
deploying Redis. Record the workflow run URL, commit SHA, and elapsed task time.
After Redis is deployed, trigger the same dev workflow with an equivalent
content state and record the same values. Compare elapsed time rather than CPU
time, and repeat when the two runs differ materially.

Also record the RDS instance size and Drupal instance count for both runs.
Those values affect the number of concurrent database connections and can make
static generation slower even when cache traffic is removed from MySQL.
