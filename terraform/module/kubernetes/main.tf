locals {
  vms = {
    "talos-CP-01" = {
      hostname     = "talos-CP-01"
      id           = 1001
      target_node  = "homelab"
      memory       = 4096
      cpu          = 2
      ip_address   = "192.168.1.130"
      gateway      = "192.168.1.1"
      install_disk = "/dev/sda"
    },
    "talos-ND-01" = {
      hostname     = "talos-ND-01"
      id           = 1002
      target_node  = "homelab"
      memory       = 8192
      cpu          = 4
      ip_address   = "192.168.1.200"
      gateway      = "192.168.1.1"
      install_disk = "/dev/sda"
    },
  }

  kubernetes = {
    cluster = {
      name = "talos-cluster"
      ip   = "192.168.1.130"
    }

    controlplanes = {
      for k, v in local.vms :
      k => v
      if can(regex("CP", k))
    }

    workers = {
      for k, v in local.vms :
      k => v
      if can(regex("ND", k))
    }
  }
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.vms

  name      = each.key
  node_name = each.value.target_node
  vm_id     = each.value.id

  boot_order = ["scsi0", "scsi1"]

  agent {
    enabled = false #QEMU
    timeout = "1m"
    type    = "virtio"
  }

  scsi_hardware = "virtio-scsi-pci"
  machine       = "q35"

  cdrom {
    interface = "scsi1"
    file_id   = "local:iso/talos-nocloud-amd64.1.13.4.iso"
  }

  disk {
    interface   = "scsi0"
    size        = "32"
    file_format = "raw"
    cache       = "writethrough"
    ssd         = false
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
    floating  = 0
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/24"
        gateway = each.value.gateway
      }
    }
  }
}

resource "talos_machine_secrets" "this" {
  talos_version = "v1.13.4"
}

data "talos_machine_configuration" "controlplane" {
  for_each         = local.kubernetes.controlplanes
  cluster_name     = local.kubernetes.cluster.name
  cluster_endpoint = "https://${local.kubernetes.cluster.ip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "worker" {
  for_each         = local.kubernetes.workers
  cluster_name     = local.kubernetes.cluster.name
  cluster_endpoint = "https://${local.kubernetes.cluster.ip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = local.kubernetes.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in local.kubernetes.controlplanes : v.ip_address]
}

resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [
    proxmox_virtual_environment_vm.talos
  ]

  for_each = local.kubernetes.controlplanes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane[each.key].machine_configuration
  node                        = each.value.ip_address

  config_patches = [
    templatefile("${path.module}/templates/talos.yaml.tmpl", {
      install_disk = each.value.install_disk
      ip_address   = each.value.ip_address
      gateway      = each.value.gateway
    }),
    file("${path.module}/files/cp-scheduling.yaml"),
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in local.kubernetes.controlplanes : v.ip_address][0]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in local.kubernetes.controlplanes : v.ip_address][0]
}

resource "talos_machine_configuration_apply" "worker" {
  depends_on = [talos_cluster_kubeconfig.this]

  for_each = local.kubernetes.workers

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  node                        = each.value.ip_address

  config_patches = [
    templatefile("${path.module}/templates/talos.yaml.tmpl", {
      install_disk = each.value.install_disk
      ip_address   = each.value.ip_address
      gateway      = each.value.gateway
    })
  ]
}