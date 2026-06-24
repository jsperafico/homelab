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

- [ ] Use [Azure Key Vault](https://azure.microsoft.com/pt-br/products/key-vault) to securely storage my secrets and keys
- [ ] Use [Ansible](https://docs.ansible.com/) to manage updates on VMs and BareMetal.
- [ ] Use [GitHub](https://github.com/) action to persist changes on my Homelab by creating a private on-the-fly private connection on [Pangolin](https://pangolin.net/).
- [ ] Use [OpenTofu](https://opentofu.org/) to provision virtual machines at Proxmox instance.
  - [ ] [Open Media Vault](https://www.openmediavault.org/) as NAS Solution containing:
    - [X] SMB shared folder for every user with quota.
    - [X] NFS shared PostgreSQL folder.
    - [X] NFS shared Kubernetes folder.
  - [X] [PostgreSQL](https://www.postgresql.org/) connected to NFS shared folder.
  - [X] [Talos Linux](https://www.talos.dev/) as my Kubernetes Solution:
    - [X] 1 ControlPlane
    - [X] 1 Worker
    - [X] Through ControlPlane, worker should have access to NFS shared folder.
  - [ ] [Forgejo](https://forgejo.org/) as an alternative to GitHub when regards to comissioned work.
    - [X] Migrate existing projects to Self-Hosted instance.
    - [ ] Streamline Kubernetes deployments.
    - [ ] Manage Newt connections to different kubernetes applications based on comissioned projects.
  - [ ] [Ubuntu 26.04](https://releases.ubuntu.com/resolute/) as Gaming Station.
    - [ ] GPU just died. RIP. So, this step is on hold until further budget.
- [ ] On Kubernetes use [Flux](https://fluxcd.io/) as GitOps, likely with OpenTofu as well.


## Repository Overview

| Folder    | Purpose                                  |
| --------- | ---------------------------------------- |
| terraform | Folder where tofu artefacts are located. |


## Open Media Vault

Since my OMV instance isn't being managed by Terraform, it would be quite difficult to identify what version I am using, right?
So, currently I have `8.4.0-3 (Synchrony)` vertsion on a `Linux 7.0.10+deb13-amd64` kernel.

What I have done manually on OMV was:
1. Enable the following plugins `openmediavault-filebrowser 8.0.6-1` and `openmediavault-md 8.1.2-2`.
2. Wipe both of my HDD disks being `/dev/sdb` and `/dev/sdc`.
3. Mirror (RAID 1) both of them, in the Multiple Device pannel.
4. Create a file system for the device `/dev/md0` being the output of the Mirroring.
5. Created a shared folders for `kubernetes`, `postgres` and `userdir` on `/dev/md0` with no extra caveats or ACL:
6. Under `Services` -> `NFS`, I created both:
   1. kubernetes:
      - Shared Folder: `kubernetes [on /dev/md0, kubernetes/]`
      - Client: `192.168.1.0/24` - I am aware this isn´t recommended, but at the same time it is just a homelab.
      - Permission: `Read/Write`
      - Extra Options: `subtree_check,insecure,no_subtree_check,no_root_squash`
   2. postgres:
      - Shared Folder: `postgres [on /dev/md0, postgres/]`
      - Client: `192.168.1.110/24` - I am aware this isn´t recommended, but at the same time it is just a homelab.
      - Permission: `Read/Write`
      - Extra Options: `subtree_check,insecure,no_root_squash`
7. Under `Services` -> `SMB` -> `Settings`:
   1. `Enabled` the service itself
   2. `Enabled` home directories

Despite my best efforts, there was little to be done when regards to Open Media Vault on terraform.
As it is, there is no reliable provider where allows me to:

- Create a New User
- Change Admin Password
- Wipe Disks
- Create RAID 1 between two passthrough drivers
- Set User Quota on a given File System
- Create Shared Folders
- Enable SMB and NFS Services

## PostgreSQL

Yes, I know that my configuration goes against best practices of DevOps. It isn't a critical database, so saving the data inside NFS should be just fine.
Both OpenMediaVault and PostgreSQL live inside the same host as VMs, so it should be just fine.
In any case, I will not have too many accesses to the database, since it will for development purposes.

Sure, I could just use a pod inside kubernetes but - in my opinion - create pods for database every time I want just to try things out it would be a waste of resources.

## Open Tofu

Useful tips when using terraform:

| Command                   | Purpose                                         |
| ------------------------- | ----------------------------------------------- |
| `tofu init`               | Download providers.                             |
| `tofu plan`               | Verify the expected changes without running it. |
| `tofu apply`              | Apply changes to infra.                         |
| `tofu destroy`            | Destroy previously-created infrastructure.      |
| `tofu output -raw xxxxxx` | Print on console the respective output          |

## Forgejo

Previously I had a self-hosted gitlab instance that not only required a quite large amount of resources but also too complicated to manage.
Now, hoping to simplify my like, I have chosen Forgejo as my self-hosted VCS. Quite easily to migrate things to be honest.
