# Controlled Egress Proxy

Deploys the [GSA-TTS cg-egress-proxy](https://github.com/GSA-TTS/cg-egress-proxy) so that
applications in the `dev`, `staging` and `prod` spaces can reach a small allowlist of
external hosts without those spaces holding the `public_networks_egress` security group.

One proxy application per environment, all running in a shared space that does hold
`public_networks_egress`.

## Why this is a separate root configuration

Everything under `../infra` runs on `cloudfoundry-community/cloudfoundry`. The
cg-egress-proxy module requires the official `cloudfoundry/cloudfoundry` provider, and the
two cannot coexist in one root module — Terraform resolves provider references by *type*,
and both providers have the type `cloudfoundry`, so a second local name does not
disambiguate them.

Rather than migrate the whole `../infra` tree to the official provider, egress lives here on
its own. `../infra` is untouched.

## State

Uses the same PostgreSQL backend as `../infra`, but with
`schema_name = "terraform_remote_state_egress"`.

**This must stay distinct.** The `pg` backend keys state by workspace name within one
schema and table, so sharing the default `terraform_remote_state` schema would make this
configuration's `dev` state collide with the infra `dev` state.

## Prerequisites

The `shared-egress` space must exist and hold `public_networks_egress` on both the running
and staging lifecycles. Creating a space needs OrgManager, so it is done once by hand rather
than from this configuration:

```bash
cf create-space shared-egress -o "$CF_ORG"
cf bind-security-group public_networks_egress "$CF_ORG" --space shared-egress --lifecycle running
cf bind-security-group public_networks_egress "$CF_ORG" --space shared-egress --lifecycle staging
```

The pipeline's service account must also be given a role on the new space. `cf create-space`
grants SpaceDeveloper only to the user who runs it, and
`../bootstrap/create_service_account.sh` grants roles by looping over the spaces that
existed **when it was run** — so a space created later is invisible to the pipeline, and
`tofu plan` fails when the `cloudfoundry_space` data source cannot find it:

```bash
username=$(cf service-key pipeline pipeline-key | tail -n +3 | jq -r '.credentials.username')
cf set-space-role "$username" "$CF_ORG" shared-egress SpaceDeveloper
```

## Rolling out an environment

One repository variable, **`EGRESS_SPACES`**, controls the whole feature. It is a
space-separated list of environments:

```
EGRESS_SPACES = "dev"                 # then "dev staging", then "dev staging prod"
```

Unset means the feature is off everywhere — Terraform deploys no proxy and the lockdown
step is skipped — so the code can be merged and deployed with no effect anywhere.

Adding a space does two things on the next deploy to it:

1. `terraform/egress` builds `digital-gov-proxy-<space>`, the per-client credential
   services and the network policies.
2. `scripts/pipeline/cloud-gov-egress-asg.sh` removes `public_networks_egress` from that
   space's **running** lifecycle.

They happen in that order within one deploy: `deploy-infra` builds the proxy, and the
lockdown runs last in `deploy-app`.

### Why one variable and not two

Building a proxy and removing public egress are two phases, but they are not independent:
"locked down without a proxy" is not a state anyone wants, and two lists that must be kept
in sync would make it reachable by a single mistaken edit.

Safety is derived instead of duplicated. Before unbinding anything the script requires:

- the proxy application for that space exists and is `STARTED`
- the client application is bound to its egress credential service

The variable expresses intent; those checks confirm reality. It cannot be put into an
invalid state by editing the variable alone.

### Verifying

Check from inside a **freshly created** container — `cf run-task` is reliable, `cf ssh` has
proved flaky:

```bash
cf run-task <app> --command '...' -m 1G -k 2G --wait
```

**Security group changes take minutes to propagate.** A container started immediately
after a change may still have public egress and give a false pass. Confirm that a direct
request to a non-allowlisted host is refused before trusting the result.

### Temporarily restoring egress, with the variable left set

For testing, or to unblock something quickly, public egress can be restored without
touching `EGRESS_SPACES`:

```bash
cf bind-security-group public_networks_egress "$CF_ORG" --space <space> --lifecycle running
```

This holds until the **next deploy to that space**, which will remove it again. Only
`cloudgov-deploy-app.yml` runs the lockdown — the `generate-static` cron workflows do not
— so scheduled jobs will not undo it.

Note again that security group changes take minutes to propagate, in both directions.

### Backing a space out, durably

Remove it from `EGRESS_SPACES`, then re-bind by hand:

```bash
cf bind-security-group public_networks_egress "$CF_ORG" --space <space> --lifecycle running
```

Removing the space stops enforcement and stops the proxy being managed; it does not
re-open egress on its own. That is deliberate — a security control should not switch
itself off because a variable was cleared.

## Adding an application to the proxy

Three parts: declare the client, bind its credentials, and tell the application to use
them. All three are required — a client with no binding gets credentials nothing reads,
and a binding with no consumer configuration is inert.

### 1. Declare the client

In `locals.tf`, add an entry to `clients`. `app` is the Cloud Foundry application name,
used to look the application up for the network policy and to place the credential service
in the right space.

```hcl
clients = {
  cms = {
    app       = format(local.name_pattern, "drupal")
    allowlist = []                          # base_allowlist is added automatically
  }

  waf = {
    app       = format(local.name_pattern, "waf")
    allowlist = ["example.gov"]             # anything beyond the shared base list
  }
}
```

This creates, for each client: its own credentials, a `digital-gov-egress-<client>-<space>`
user-provided service in the application's space, and a network policy to the proxy on
61443. Credentials and ACLs are per client, so one client cannot use another's grants.

### 2. Bind the credential service

How depends on how the application is deployed.

**Deployed from `manifest.yml`** (the CMS): follow the existing
`# EGRESS_SERVICE_BINDING` placeholder. `scripts/pipeline/cloud-gov-deploy.sh` replaces it
only when the service exists, so environments without a proxy still deploy. Add a second
placeholder and matching conditional for a second such application.

**Deployed by Terraform** (the WAF, the bastions, a future log shipper): their bindings
live in `terraform/infra`, which cannot reference a service created here — separate
configurations, separate state. Set `bind_service = true` on the client and this
configuration makes the binding itself:

```hcl
logshipper = {
  app          = format(local.name_pattern, "logshipper")
  allowlist    = []
  bind_service = true
}
```

**Use exactly one path per client.** Setting `bind_service` on an application that is also
bound through `manifest.yml` would give one binding two owners.

### 3. Tell the application to use the proxy

Read `proxy_uri` from the bound service and configure the specific consumer that needs it.
`scripts/bootstrap.sh` has the pattern:

```bash
proxy_uri=$(echo "${VCAP_SERVICES}" | jq -r '[."user-provided"[]? | select(any(.tags[]?; . == "egress-proxy")) | .credentials.proxy_uri] | first // empty')
```

Located by tag rather than service name, so it survives renaming.

**Do not export `http_proxy`/`https_proxy` globally.** Each consumer opts in individually,
so that S3 traffic keeps going direct — the AWS S3 Gateway ranges are already permitted by
`trusted_local_networks_egress`, and routing `aws s3 sync` through the proxy would break
the static site build. If you do set them for a specific process, `no_proxy`
must cover `apps.internal`, the site's own hostnames **and** the S3 endpoints — see the
table below for why S3 matters there even though it does not here.

The CMS has two separate consumers, which is the pattern to copy:

| consumer | where | what it covers |
|---|---|---|
| New Relic PHP daemon | `scripts/bootstrap.sh` writes `newrelic.daemon.proxy` into `newrelic.ini` | the daemon ignores `http_proxy`; this ini key is the only thing it reads |
| Drupal's HTTP client | `$settings['http_client_config']['proxy']` in `settings.cloudgov.php` | every server-side Guzzle call — OpenID Connect, media oEmbed |

The Drupal one carries a `no` list, and it is load-bearing:

```php
$settings['http_client_config']['proxy']['no'] = [
  'localhost', '127.0.0.1',
  'apps.internal',                             // container-to-container
  's3-fips.us-gov-west-1.amazonaws.com',       // Guzzle suffix-matches, so
  's3.us-gov-west-1.amazonaws.com',            // <bucket>.s3-fips... is covered
];
```

The entries fall into three kinds, and the reasons differ:

- **`apps.internal`** — container-to-container routing must not go through a proxy.
- **The site's own hostnames** — `convert_text` fetches
  `\Drupal::request()->getSchemeAndHttpHost()` to resolve unrouted paths, from
  `/admin/convert-text` as well as from migrations. The proxy is never the route from the
  application back to itself.
- **S3** — *defensive, not load-bearing.* Neither of the two things that actually talk to
  S3 reads this setting:
  - `aws s3 sync` is a separate process. It reads `http_proxy` from the environment,
    which is deliberately not exported, so `http_client_config` is invisible to it.
  - `s3fs` **is** enabled — via the `non_local` config split, not `core.extension.yml` —
    but it uses the AWS SDK, which builds its own Guzzle client and never reads
    `Settings::get('http_client_config')`.

  These entries cover a `\Drupal::httpClient()` call that targets S3 directly. They are
  derived from the bound credential rather than hardcoded, so they cannot drift from the
  endpoint actually in use.

**The stronger reason for per-consumer opt-in.** Guzzle's `configureDefaults()` reads
`HTTPS_PROXY` from the environment in *any* SAPI — only `HTTP_PROXY` is CLI-gated. So
exporting `HTTPS_PROXY` anywhere in the container would silently route the AWS SDK,
including anything using it for S3, through the proxy, and only the `NO_PROXY` environment
variable — not this PHP setting — would prevent it. If you ever do export proxy variables
for a specific process, `NO_PROXY` must list the S3 endpoints as well as `apps.internal`.

### Expected 403s

Two enabled modules reach hosts that are deliberately not allowlisted, and will log proxy
403s. These are not faults:

| module | host | effect |
|---|---|---|
| `update` | `updates.drupal.org` | Available Updates page reports an error |
| `upgrade_status` | `drupal.org` | project data unavailable, admin-only |

**When checking which modules are enabled, read the config splits as well as
`core.extension.yml`.** `config/sync/config_split.config_split.non_local.yml` enables
`s3fs` and `new_relic_rpm` in every cloud.gov environment, and neither appears in
`core.extension.yml`. Two separate reviews of this work both concluded s3fs was disabled
by reading only the latter.

Both degrade to an error message rather than breaking the site. Allowlisting either is a
one-line change if the noise is not wanted.

**A host allowlisted here must match what the application actually requests.** The OIDC
plugin builds its endpoints from `okta_domain`, which differs between environments
(`auth-preprod.gsa.gov` for dev and staging, `auth.gsa.gov` in the production config
split), so both are listed. Caddy's ACL matches the CONNECT host, so a redirect elsewhere
would not help.

### A caution about the WAF specifically

The WAF is used above as a worked example, but it is **not** a good proxy candidate today,
and is deliberately excluded. Its outbound traffic is `proxy_pass` to S3 and to Drupal over
`apps.internal`, both already permitted without the proxy — and nginx cannot use an HTTP
`CONNECT` proxy for `proxy_pass` at all, so pointing it at one would not work.

It would only become a client if it gained something that speaks to the internet and
honours a proxy setting, such as a New Relic agent. The same is true of
`database-backup-bastion`, which only reaches S3 and RDS.

The application that genuinely needs this next is `tf-bastion` — it downloads OpenTofu from
GitHub on every start. That is tracked separately.

## Rotating credentials

These are the HTTP Basic auth credentials Caddy's `forward_proxy` checks.

**Policy: rotate only on suspected compromise.** GSA recommends annual rotation, but these
credentials are low value and no schedule is kept. Rotation is an exception, not routine.

### The blunt way — causes a brief outage

Change `credential_version` in `locals.tf`. This is the only thing that rotates
credentials; an allowlist or code change cannot do it accidentally.

It rotates **every** client at once. `VCAP_SERVICES` is injected at container start, so a
running application keeps its old credentials until it restarts — and until it does, its
proxied traffic gets 407. Each client application must be restarted afterwards.

### The zero-downtime way — preferred

Because each entry in `clients` gets its own credentials *and* its own ACL, and the
generated Caddyfile contains one `forward_proxy` block per client, two sets of credentials
can be valid at the same time:

1. Add a second client alongside the first with the same allowlist, e.g. `cms_next`.
2. Apply. Both credential sets are now accepted.
3. Repoint the application at the new credential service and restart it.
4. Remove the original client entry.
5. Apply. The old credentials stop working.

No window exists where the application holds credentials the proxy will not accept. Leave
`credential_version` alone when doing this — it is the all-at-once lever, not this one.

## Testing

See the Troubleshooting section of the
[cg-egress-proxy README](https://github.com/GSA-TTS/cg-egress-proxy/blob/main/README.md),
and Appendix A of `egress-plan.md` in the repository root.
