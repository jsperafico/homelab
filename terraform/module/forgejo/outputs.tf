output "forgejo-cloud-init" {
  value = {
    for k, v in proxmox_virtual_environment_file.cloudinit : k => v.source_raw[0].data
  }
  sensitive = true
}

output "forgejo_default_ip" {
  value = split(
    "/",
    proxmox_virtual_environment_vm.forgejo["forgejo-01"]
    .initialization[0]
    .ip_config[0]
    .ipv4[0]
    .address
  )[0]
}