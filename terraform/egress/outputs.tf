## Consumed by the next step, which binds these credentials to the client applications
## as user-provided services. Sensitive: these are live proxy credentials.

output "proxy_app_id" {
  description = "GUID of the egress proxy application, for network policies."
  value       = local.enabled ? module.egress_proxy[0].app_id : null
}

output "proxy_domain" {
  description = "Internal route of the egress proxy, e.g. digital-gov-proxy-dev.apps.internal"
  value       = local.enabled ? module.egress_proxy[0].domain : null
}

output "proxy_credentials" {
  description = "Per-client proxy URIs, keyed by client name."
  value       = local.enabled ? module.egress_proxy[0].https_proxy : {}
  sensitive   = true
}
