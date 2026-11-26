#cloud-config

hostname: ${hostname}
manage_etc_hosts: true

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
  - curl
  - wget
  - ca-certificates
  - nfs-common
  - qemu-guest-agent

write_files:
  - path: /usr/local/bin/configure-adguard.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail

      # Disable systemd-resolved DNS stub listener
      mkdir -p /etc/systemd/resolved.conf.d

      cat > /etc/systemd/resolved.conf.d/adguardhome.conf <<EOF
      [Resolve]
      DNS=127.0.0.1
      DNSStubListener=no
      EOF

      ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

      systemctl restart systemd-resolved

      INSTALL_DIR="/opt/AdGuardHome"
      CONFIG_DIR="/adguard/conf"
      WORK_DIR="/adguard/work"

      # Ensure OMV storage is mounted
      mount -a

      if ! mountpoint -q /adguard; then
          echo "ERROR: OMV NFS mount unavailable"
          exit 1
      fi

      # Install AdGuard Home if the binary does not exist
      if [ ! -x "$INSTALL_DIR/AdGuardHome" ]; then
          curl -fsSL \
              https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh \
              -o /tmp/adguard-install.sh

          sh /tmp/adguard-install.sh -o /opt -v
          rm -f /tmp/adguard-install.sh
      fi

      # Stop the installer-created service
      systemctl stop AdGuardHome || true

      # Prepare persistent directories on OMV
      mkdir -p "$CONFIG_DIR" "$WORK_DIR"

      # Migrate existing configuration if one exists
      if [ ! -f "$CONFIG_DIR/AdGuardHome.yaml" ] && \
        [ -f "$INSTALL_DIR/AdGuardHome.yaml" ]; then
          cp "$INSTALL_DIR/AdGuardHome.yaml" \
            "$CONFIG_DIR/AdGuardHome.yaml"
      fi

      # Preserve existing data if the persistent work directory is empty
      if [ -d "$INSTALL_DIR/data" ] && \
        [ -z "$(ls -A "$WORK_DIR" 2>/dev/null)" ]; then
          cp -a "$INSTALL_DIR/data/." "$WORK_DIR/"
      fi

      # Remove the installer-created service
      "$INSTALL_DIR/AdGuardHome" -s uninstall || true

      # Install service using persistent configuration and work directories
      "$INSTALL_DIR/AdGuardHome" \
          -s install \
          -c "$CONFIG_DIR/AdGuardHome.yaml" \
          -w "$WORK_DIR"

      # Make sure NFS is mounted before AdGuard starts
      mkdir -p /etc/systemd/system/AdGuardHome.service.d

      cat > /etc/systemd/system/AdGuardHome.service.d/omv.conf <<EOF
      [Unit]
      Wants=network-online.target
      After=network-online.target remote-fs.target
      RequiresMountsFor=/adguard
      EOF

      systemctl daemon-reload
      systemctl enable AdGuardHome
      systemctl start AdGuardHome

      echo "AdGuard Home installed and started."
      echo "Complete the installation wizard at http://192.168.1.70:3000"

mounts:
  - [
      "${omv_ip}:${nfs_export}",
      "/adguard",
      "nfs4",
      "rw,hard,timeo=600,retrans=2,_netdev",
      "0",
      "0",
    ]

runcmd:
  - [systemctl, enable, qemu-guest-agent]
  - [systemctl, start, qemu-guest-agent]
  - bash /usr/local/bin/configure-adguard.sh
