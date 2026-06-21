output "kubeconfig" {
  value     = module.kubernetes.kubeconfig
  sensitive = true
}

output "talosconfig" {
  value     = module.kubernetes.talosconfig
  sensitive = true
}