variable "PM_IP" {
  type = string
}

variable "PM_USER" {
  type = string
}

variable "PM_PASS" {
  type      = string
  sensitive = true
}

variable "PM_ID_TOKEN" {
  type = string
}

variable "PM_TOKEN" {
  type      = string
  sensitive = true
}

variable "UBUNTU_USER" {
  type = string
}

variable "UBUNTU_PASS" {
  type      = string
  sensitive = true
}

provider "proxmox" {
  endpoint  = "https://${var.PM_IP}:8006/"
  api_token = "${var.PM_ID_TOKEN}=${var.PM_TOKEN}"
  insecure  = true

  ssh {
    username = var.PM_USER
    password = var.PM_PASS

    agent = true
  }
}

provider "talos" {}

module "kubernetes" {
  source = "./module/kubernetes"

  providers = {
    proxmox = proxmox
    talos   = talos
  }
}

module "postgres" {
  source = "./module/postgres"

  providers = {
    proxmox = proxmox
  }

  UBUNTU_USER = var.UBUNTU_USER
  UBUNTU_PASS = var.UBUNTU_PASS
}