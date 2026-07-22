# Redis cache service

The Drupal application uses Valkey only when a bound Cloud.gov service has the
`cache-service` tag. Without that binding, it uses the configured default cache
backend. Local Lando development continues to use Memcached.

## Deploy

The `terraform/infra` configuration provisions a
`${PROJECT}-cache-${CF_SPACE}` `aws-elasticache-redis` service on the
`redis-3node-large` plan. It explicitly selects the Valkey 8.2 engine and tags
the service so Drupal can discover it through `VCAP_SERVICES`.

The normal build-and-deploy workflow applies infrastructure before deploying
Drupal, so the manifest can bind the new service. ElastiCache provisioning can
take a significant amount of time. After deployment, confirm the binding with:

```sh
cf env "${PROJECT}-drupal-${CF_SPACE}"
```

Verify that the cache service has the `cache-service` tag and credentials for
`hostname` or `host`, `port`, and `password`. Cloud.gov encrypts ElastiCache
connections in transit; Drupal configures Predis to use TLS.

Before deploying, confirm the target space has the
`trusted_local_networks_egress` running security group. Cloud.gov requires this
group for applications to reach brokered ElastiCache services. This repository's
OpenTofu ASG binding is disabled because of a Cloud Foundry provider limitation,
so a platform operator must add the group when it is absent.

## Measure static generation

Capture a comparable dev baseline from the `Build Static Site` workflow before
deploying Redis. Record the workflow run URL, commit SHA, and elapsed task time.
After Redis is deployed, trigger the same dev workflow with an equivalent
content state and record the same values. Compare elapsed time rather than CPU
time, and repeat when the two runs differ materially.

Also record the RDS instance size and Drupal instance count for both runs.
Those values affect the number of concurrent database connections and can make
static generation slower even when cache traffic is removed from MySQL.
