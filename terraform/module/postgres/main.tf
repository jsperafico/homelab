#omv_ip     = proxmox_virtual_environment_vm.omv.ipv4_addresses[0][0]

variable "UBUNTU_USER" {
  type = string
}

variable "UBUNTU_PASS" {
  type      = string
  sensitive = true
}

locals {
  vms = {
    "postgres-1" = {
      hostname    = "postgres-1"
      id          = 2001
      target_node = "homelab"
      memory      = 4096
      cpu         = 2
      ip_address  = "192.168.1.110"
      gateway     = "192.168.1.1"
    }
  }
}

resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "homelab"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "ubuntu-noble-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_file" "cloudinit" {
  for_each  = local.vms
  node_name = each.value.target_node

  content_type = "snippets"
  datastore_id = "local"

  source_raw {
    data = templatefile(
      "${path.module}/cloud_init.tpl",
      {
        hostname   = each.value.hostname
        omv_ip     = "192.168.1.131"
        nfs_export = "/postgres"
        user       = var.UBUNTU_USER
        pass       = var.UBUNTU_PASS
      }
    )
    file_name = "${each.value.hostname}-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "postgres" {
  for_each = local.vms

  name      = each.value.hostname
  node_name = each.value.target_node
  vm_id     = each.value.id

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  initialization {
    user_data_file_id = "local:snippets/${each.value.hostname}-cloud-init.yaml"

    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/24"
        gateway = each.value.gateway
      }
    }
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 20
  }
}