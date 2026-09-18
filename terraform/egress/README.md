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

## Rolling out an environment

`locals.tf` holds `enabled_workspaces`. Applying with a workspace that is not listed is a
safe no-op, so environments are switched on one at a time:

```hcl
enabled_workspaces = ["dev"]              # then ["dev", "staging"], then all three
```

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

Change `credential_version` in `locals.tf`. This is the only thing that rotates
credentials — an allowlist or code change cannot do it accidentally. Every client
application must be restarted afterwards to pick up the new value.

## Testing

See the Troubleshooting section of the
[cg-egress-proxy README](https://github.com/GSA-TTS/cg-egress-proxy/blob/main/README.md),
and Appendix A of `egress-plan.md` in the repository root.
