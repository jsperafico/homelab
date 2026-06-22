output "postgres-cloud-init" {
  value = {
    for k, v in proxmox_virtual_environment_file.cloudinit : k => v.source_raw[0].data
  }
  sensitive = true
}
