# Homelab Overview

At least so far, my homelab is composed as a Single Machine. Over there, I have installed [Proxmox VE](https://www.proxmox.com/en/downloads) as the operating system.
I do not own a dedicated IP address from my ISP. Therefore, do I use [Pangolin](https://pangolin.net/) as my Zero Trust Network Access. 
My laptop currently runs on windows, planning to migrate to Linux as soon as possible.

In order to create a compelling Infrastrucutre-as-Code, I use to use GitHub Actions to connect to my Homelab. 
It is connected thorugh Newt where is only enabled TCP port 22. With additional caveats regarding access and priviledges.
Once the Pangolin SSH connection is established, then I use Ansible to run Linux based modifications to my Proxmox instance.

As can be seen, it isn't fancy as most people have online. At the same time, hosting and maning your own environment is no small feat.

## TODO

There is much work to be done. I do intent to:

- [ ] Use Azure Key Vault to securely storage my secrets and keys
- [ ] Use OpenTofu to provision virtual machines at Proxmox instance.
  - [?] [Open Media Vault](https://www.openmediavault.org/) as NAS Solution.
  - [X] [Talos Linux](https://www.talos.dev/) as my Kubernetes Solution, composed of 1 ControlPlane and 1 Worker.
  - [ ] [Ubuntu 26.04](https://releases.ubuntu.com/resolute/) as Gaming Station.
- [ ] On Kubernetes use [Flux](https://fluxcd.io/) as GitOps, likely with OpenTofu as well.

## Open Media Vault

Despite my best efforts, there was little to be done when regards to Open Media Vault.
As it is, there is no reliable provider where allows me to:

- Create a New User
- Change Admin Password
- Wipe Disks
- Create RAID 1 between two passthrough drivers
- Set User Quota on a given File System
- Create Shared Folders
- Enable SMB and NFS Services

## Repository Overview

| Folder    | Purpose                                  |
| --------- | ---------------------------------------- |
| terraform | Folder where tofu artefacts are located. |

## Open Tofu

Useful tips when using terraform:

| Command                   | Purpose                                         |
| ------------------------- | ----------------------------------------------- |
| `tofu init`               | Download providers.                             |
| `tofu plan`               | Verify the expected changes without running it. |
| `tofu apply`              | Apply changes to infra.                         |
| `tofu destroy`            | Destroy previously-created infrastructure.      |
| `tofu output -raw xxxxxx` | Print on console the respective output          |
