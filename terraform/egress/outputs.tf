## Informational. The credential services and network policies are created in main.tf;
## these outputs exist for debugging and for any future configuration that needs to
## reference the proxy. Sensitive: proxy_credentials holds live credentials.

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
