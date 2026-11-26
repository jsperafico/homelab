output "adguard_default_ip" {
  value = split(
    "/",
    proxmox_virtual_environment_vm.adguard["adguard-01"]
    .initialization[0]
    .ip_config[0]
    .ipv4[0]
    .address
  )[0]
}