output "kubeconfig" {
  value     = module.kubernetes.kubeconfig
  sensitive = true
}

output "talosconfig" {
  value     = module.kubernetes.talosconfig
  sensitive = true
}

output "postgres-cloud-init" {
  value     = module.postgres.postgres-cloud-init
  sensitive = true
}

output "forgejo-cloud-init" {
  value     = module.forgejo.forgejo-cloud-init
  sensitive = true
}

