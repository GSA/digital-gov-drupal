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

Add an entry to `clients` in `locals.tf`. Each client gets its own credentials and its own
ACL, so no client can use another's grants. The application does **not** need to be
Terraform-managed — `digital-gov-drupal` is deployed from `manifest.yml`.

```hcl
clients = {
  cms = {
    allowlist = []                         # base_allowlist is added automatically
  }
}
```

Then give the application its proxy configuration. Note that setting `http_proxy` globally
is deliberately avoided: each consumer opts in individually, so that S3 traffic keeps going
direct rather than being routed through the proxy.

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
