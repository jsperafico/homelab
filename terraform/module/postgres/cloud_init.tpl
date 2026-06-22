#cloud-config

hostname: ${hostname}

package_update: true
package_upgrade: true

users:
  - name: ${user}
    groups: sudo
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    lock_passwd: false

chpasswd:
  list: |
    ${user}:${pass}
  expire: false

ssh_pwauth: true

packages:
  - postgresql
  - postgresql-contrib
  - nfs-common
  - qemu-guest-agent
  - curl

write_files:
  - path: /usr/local/bin/configure-postgres.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -eux

      PGVER=$(ls /etc/postgresql | head -1)
      DATA_DIR="/pgdata/data"

      mount -a

      systemctl stop postgresql || true

      if [ ! -d "$DATA_DIR" ]; then
          sudo -u postgres mkdir -p "$DATA_DIR"
          sudo -u postgres chmod 700 "$DATA_DIR"

          sudo -u postgres /usr/lib/postgresql/$${PGVER}/bin/initdb \
            -D "$DATA_DIR"
      fi

      sed -i "s|^data_directory.*|data_directory = '$DATA_DIR'|" /etc/postgresql/$${PGVER}/main/postgresql.conf || true

      systemctl enable postgresql
      systemctl restart postgresql

mounts:
  - [
      "${omv_ip}:${nfs_export}",
      "/pgdata",
      "nfs4",
      "rw,hard,timeo=600,retrans=2",
      "0",
      "0",
    ]

runcmd:
  - [systemctl, daemon-reload]
  - [systemctl, enable, qemu-guest-agent]
  - [systemctl, start, qemu-guest-agent]
  - bash /usr/local/bin/configure-postgres.sh
