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

provider "helm" {
  kubernetes = {
    host = yamldecode(module.kubernetes.kubeconfig).clusters[0].cluster.server

    client_certificate     = base64decode(yamldecode(module.kubernetes.kubeconfig).users[0].user.client-certificate-data)
    client_key             = base64decode(yamldecode(module.kubernetes.kubeconfig).users[0].user.client-key-data)
    cluster_ca_certificate = base64decode(yamldecode(module.kubernetes.kubeconfig).clusters[0].cluster.certificate-authority-data)
  }
}

provider "kubernetes" {
  host = yamldecode(module.kubernetes.kubeconfig).clusters[0].cluster.server

  client_certificate     = base64decode(yamldecode(module.kubernetes.kubeconfig).users[0].user.client-certificate-data)
  client_key             = base64decode(yamldecode(module.kubernetes.kubeconfig).users[0].user.client-key-data)
  cluster_ca_certificate = base64decode(yamldecode(module.kubernetes.kubeconfig).clusters[0].cluster.certificate-authority-data)
}


module "kubernetes" {
  source = "./module/kubernetes"

  providers = {
    proxmox    = proxmox
    talos      = talos
    helm       = helm
    kubernetes = kubernetes
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