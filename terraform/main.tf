variable "PM_IP" {
  type = string
}

variable "PM_USER" {
  type = string
}

variable "PM_PASS" {
  type = string
}

variable "PM_ID_TOKEN" {
  type = string
}

variable "PM_TOKEN" {
  type = string
}

provider "proxmox" {
  endpoint  = "https://${var.PM_IP}:8006/"
  api_token = "${var.PM_ID_TOKEN}=${var.PM_TOKEN}"
  insecure  = true
}

provider "talos" {}

module "kubernetes" {
  source = "./module/kubernetes"

  providers = {
    proxmox = proxmox
    talos   = talos
  }
}