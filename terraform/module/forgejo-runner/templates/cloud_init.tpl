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
  - wget
  - curl
  - jq
  - gnupg
  - qemu-guest-agent

write_files:
  - path: /usr/local/bin/configure-forgejo-runner.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euxo pipefail

      ARCH=$(uname -m)

      case "$ARCH" in
        x86_64) ARCH=amd64 ;;
        aarch64) ARCH=arm64 ;;
      esac

      export RUNNER_VERSION=$(curl -X 'GET' https://data.forgejo.org/api/v1/repos/forgejo/runner/releases/latest | jq .name -r | cut -c 2-)
      export FORGEJO_URL="https://code.forgejo.org/forgejo/runner/releases/download/v$${RUNNER_VERSION}/forgejo-runner-$${RUNNER_VERSION}-linux-$${ARCH}"

      wget -O forgejo-runner $${FORGEJO_URL} || curl -o forgejo-runner $${FORGEJO_URL}

      wget -O forgejo-runner.asc $${FORGEJO_URL}.asc || curl -o forgejo-runner.asc $${FORGEJO_URL}.asc
      gpg --keyserver hkps://keys.openpgp.org --recv EB114F5E6C0DC2BCDD183550A4B61A2DC5923710
      gpg --verify forgejo-runner.asc forgejo-runner && echo "✓ Verified" || echo "✗ Failed"

      install -m 755 forgejo-runner /usr/local/bin/forgejo-runner

      /usr/local/bin/forgejo-runner -v

      useradd --create-home runner

      mkdir -p /var/lib/forgejo-runner/work
      chown -R runner:runner /var/lib/forgejo-runner

      set +x
      cat > /home/runner/runner-config.yml <<EOF
      log:
        level: info
        job_level: info

      runner:
        file: .runner
        capacity: 1
        timeout: 3h
        shutdown_timeout: 3h
        insecure: false
        fetch_timeout: 30s
        fetch_interval: 2s
        report_interval: 1s
        labels:
          - self-hosted:host

      host:
        workdir_parent: /var/lib/forgejo-runner/work

      server:
        connections:
          forgejo:
            url: http://${forgejo_domain}
            uuid: ${runner_uuid}
            token: ${runner_token}

      EOF

      chown runner:runner /home/runner/runner-config.yml

  - path: /etc/systemd/system/forgejo-runner.service
    permissions: "0644"
    content: |
      [Unit]
      Description=Forgejo Runner
      Documentation=https://forgejo.org/docs/latest/admin/actions/
      After=network-online.target
      Wants=network-online.target

      [Service]
      ExecStart=/usr/local/bin/forgejo-runner daemon -c /home/runner/runner-config.yml
      ExecReload=/bin/kill -s HUP $MAINPID

      # This user and working directory must already exist
      User=runner
      WorkingDirectory=/home/runner
      Restart=on-failure
      # allow configured shutdown_timeout to be effective, rather than overridden by systemd
      TimeoutStopSec=infinity
      RestartSec=10

      [Install]
      WantedBy=multi-user.target

runcmd:
  - bash /usr/local/bin/configure-forgejo-runner.sh
  - systemctl daemon-reload
  - curl -fsSL https://deb.nodesource.com/setup_26.x | bash -
  - apt-get install -y nodejs
  - systemctl enable forgejo-runner
  - systemctl start forgejo-runner
  - systemctl enable --now qemu-guest-agent
