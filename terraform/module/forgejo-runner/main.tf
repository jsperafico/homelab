variable "UBUNTU_USER" {
  type = string
}

variable "UBUNTU_PASS" {
  type      = string
  sensitive = true
}

variable "UBUNTU_CLOUD_IMAGE_ID" {
  type = string
}

variable "FORGEJO_IP" {
  type = string
}

variable "FORGEJO_RUNNER_UUID" {
  type = string
}

variable "FORGEJO_RUNNER_TOKEN" {
  type = string
}

locals {
  vms = {
    "forgejo-runner-01" = {
      hostname     = "forgejo-runner-01"
      id           = 3002
      target_node  = "homelab"
      memory       = 2048
      cpu          = 2
      ip_address   = "192.168.1.120"
      gateway      = "192.168.1.1"
      install_disk = "/dev/sda"
      order = {
        index      = 4
        up_delay   = 120
        down_delay = 30
      }
      forgejo = {
        uuid  = var.FORGEJO_RUNNER_UUID
        token = var.FORGEJO_RUNNER_TOKEN
      }
    },
  }
}

resource "proxmox_virtual_environment_file" "cloudinit" {

  for_each  = local.vms
  node_name = each.value.target_node

  content_type = "snippets"
  datastore_id = "local"

  source_raw {
    data = templatefile(
      "${path.module}/templates/cloud_init.tpl",
      {
        hostname          = each.value.hostname
        user              = var.UBUNTU_USER
        pass              = var.UBUNTU_PASS
        forgejo_runner_ip = each.value.ip_address
        forgejo_domain    = "${var.FORGEJO_IP}:3000"
        runner_uuid       = each.value.forgejo.uuid
        runner_token      = each.value.forgejo.token
      }
    )
    file_name = "${each.value.hostname}-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "forgejo-runner" {
  depends_on = [proxmox_virtual_environment_file.cloudinit]

  for_each = local.vms

  name      = each.key
  node_name = each.value.target_node
  vm_id     = each.value.id

  agent {
    enabled = true #QEMU
    timeout = "1m"
    type    = "virtio"
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
    file_id      = var.UBUNTU_CLOUD_IMAGE_ID
    interface    = "scsi0"
    size         = 20
  }

  startup {
    order      = each.value.order.index
    up_delay   = each.value.order.up_delay
    down_delay = each.value.order.down_delay
  }
}