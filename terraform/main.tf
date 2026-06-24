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

variable "POSTGRES_ROOT" {
  type = string
}

variable "POSTGRES_PASS" {
  type      = string
  sensitive = true
}

variable "P_FORGEJO_USER" {
  type = string
}

variable "P_FORGEJO_PASS" {
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

provider "postgresql" {
  host     = module.postgres.postgres_default_ip
  username = var.POSTGRES_ROOT
  password = var.POSTGRES_PASS
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

  UBUNTU_USER   = var.UBUNTU_USER
  UBUNTU_PASS   = var.UBUNTU_PASS
  POSTGRES_PASS = var.POSTGRES_PASS
}

module "forgejo" {
  depends_on = [module.postgres]

  source = "./module/forgejo"

  providers = {
    postgresql = postgresql
    proxmox    = proxmox
  }

  UBUNTU_USER           = var.UBUNTU_USER
  UBUNTU_PASS           = var.UBUNTU_PASS
  POSTGRES_HOST         = module.postgres.postgres_default_ip
  P_FORGEJO_USER        = var.P_FORGEJO_USER
  P_FORGEJO_PASS        = var.P_FORGEJO_PASS
  UBUNTU_CLOUD_IMAGE_ID = module.postgres.ubuntu_cloud_image_id
}