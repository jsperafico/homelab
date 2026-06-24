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
  - git
  - git-lfs
  - wget
  - qemu-guest-agent
  - nfs-common

write_files:
  - path: /usr/local/bin/configure-forgejo.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -o pipefail
      set -x

      # wait for NFS mount
      timeout 60 bash -c 'until mountpoint -q /forgejo; do sleep 2; done' || true

      # create forgejo user
      if ! id forgejo >/dev/null 2>&1; then
          adduser \
            --system \
            --shell /bin/bash \
            --gecos 'Git Version Control' \
            --group \
            --disabled-password \
            --home /home/forgejo \
            forgejo
      fi

      mkdir -p \
        /forgejo/${hostname}/repositories \
        /forgejo/${hostname}/data \
        /forgejo/${hostname}/lfs \
        /forgejo/${hostname}/packages \
        /forgejo/${hostname}/attachments \
        /forgejo/${hostname}/log

      chown -R forgejo:forgejo /forgejo

      mkdir -p /etc/forgejo

      wget -O /usr/local/bin/forgejo \
        https://codeberg.org/forgejo/forgejo/releases/download/v${FORGEJO_VERSION}/forgejo-${FORGEJO_VERSION}-linux-amd64

      chmod +x /usr/local/bin/forgejo

      set +x
      cat >/etc/forgejo/app.ini <<EOF
      APP_NAME = Forgejo
      RUN_USER = forgejo

      [server]
      DOMAIN = ${forgejo_ip}
      ROOT_URL = http://${forgejo_domain}/
      APP_DATA_PATH = /forgejo/${hostname}/data

      # --- Add these SSH Specific Configurations ---
      START_SSH_SERVER = true
      SSH_PORT         = 2222
      SSH_LISTEN_PORT  = 2222

      [database]
      DB_TYPE = postgres
      HOST = ${POSTGRES_HOST}:5432
      NAME = ${db_name}
      USER = ${P_FORGEJO_USER}
      PASSWD = ${P_FORGEJO_PASS}
      SSL_MODE = disable

      [repository]
      ROOT = /forgejo/${hostname}/repositories

      [lfs]
      PATH = /forgejo/${hostname}/lfs

      [packages]
      PATH = /forgejo/${hostname}/packages

      [attachment]
      PATH = /forgejo/${hostname}/attachments

      [log]
      ROOT_PATH = /forgejo/${hostname}/log
      EOF

      set -x
      chown -R forgejo:forgejo /etc/forgejo

  - path: /etc/systemd/system/forgejo.service
    permissions: "0644"
    content: |
      [Unit]
      Description=Forgejo
      After=network.target remote-fs.target
      Wants=remote-fs.target

      [Service]
      RestartSec=2s
      Type=simple
      User=forgejo
      Group=forgejo
      WorkingDirectory=/home/forgejo
      ExecStart=/usr/local/bin/forgejo web --config /etc/forgejo/app.ini
      Restart=always

      [Install]
      WantedBy=multi-user.target

mounts:
  - [
      "${omv_ip}:${nfs_export}",
      "/forgejo",
      "nfs4",
      "rw,hard,timeo=600,retrans=2",
      "0",
      "0",
    ]

runcmd:
  - mount -a
  - bash /usr/local/bin/configure-forgejo.sh
  - systemctl daemon-reload
  - systemctl enable forgejo
  - systemctl start forgejo
