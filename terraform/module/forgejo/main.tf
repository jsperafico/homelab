variable "UBUNTU_USER" {
  type = string
}

variable "UBUNTU_PASS" {
  type      = string
  sensitive = true
}

variable "POSTGRES_HOST" {
  type = string
}

variable "P_FORGEJO_USER" {
  type = string
}

variable "P_FORGEJO_PASS" {
  type      = string
  sensitive = true
}

variable "UBUNTU_CLOUD_IMAGE_ID" {
  type = string
}

variable "FORGEJO_VERSION" {
  type    = string
  default = "15.0.3"
}

locals {
  vms = {
    "forgejo-01" = {
      hostname     = "forgejo-01"
      id           = 3001
      target_node  = "homelab"
      memory       = 4096
      cpu          = 4
      ip_address   = "192.168.1.119"
      gateway      = "192.168.1.1"
      install_disk = "/dev/sda"
    },
  }
  forgejo = {
    db_name = "forgejodb"
  }
}

resource "postgresql_role" "forgejo" {
  name     = var.P_FORGEJO_USER
  password = var.P_FORGEJO_PASS
  login    = true
}

resource "postgresql_database" "forgejodb" {
  depends_on = [postgresql_role.forgejo]

  name       = local.forgejo.db_name
  owner      = var.P_FORGEJO_USER
  template   = "template0"
  encoding   = "UTF8"
  lc_collate = "en_US.UTF-8"
  lc_ctype   = "en_US.UTF-8"
}

resource "postgresql_grant" "forgejo_privileges" {
  depends_on = [postgresql_database.forgejodb]

  database    = local.forgejo.db_name
  role        = var.P_FORGEJO_USER
  object_type = "database"
  privileges  = ["ALL"]
}

resource "proxmox_virtual_environment_file" "cloudinit" {
  depends_on = [postgresql_grant.forgejo_privileges]

  for_each  = local.vms
  node_name = each.value.target_node

  content_type = "snippets"
  datastore_id = "local"

  source_raw {
    data = templatefile(
      "${path.module}/cloud_init.tpl",
      {
        hostname        = each.value.hostname
        omv_ip          = "192.168.1.131"
        nfs_export      = "/forgejo"
        user            = var.UBUNTU_USER
        pass            = var.UBUNTU_PASS
        POSTGRES_HOST   = var.POSTGRES_HOST
        P_FORGEJO_USER  = var.P_FORGEJO_USER
        P_FORGEJO_PASS  = var.P_FORGEJO_PASS
        db_name         = local.forgejo.db_name
        FORGEJO_VERSION = var.FORGEJO_VERSION
        forgejo_ip      = each.value.ip_address
        forgejo_domain  = "${each.value.ip_address}:3000"
      }
    )
    file_name = "${each.value.hostname}-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "forgejo" {
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
}