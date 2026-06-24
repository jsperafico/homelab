output "postgres-cloud-init" {
  value = {
    for k, v in proxmox_virtual_environment_file.cloudinit : k => v.source_raw[0].data
  }
  sensitive = true
}

output "postgres_default_ip" {
  value = split(
    "/",
    proxmox_virtual_environment_vm.postgres["postgres-01"]
    .initialization[0]
    .ip_config[0]
    .ipv4[0]
    .address
  )[0]
}

output "ubuntu_cloud_image_id" {
  value = proxmox_download_file.ubuntu_cloud_image.id
}