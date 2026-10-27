# Facts give each host's architecture, which picks the release tarball.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }
}

locals {
  goarch  = { x86_64 = "amd64", aarch64 = "arm64" }
  release = { for name, f in data.conn3x_host.facts : name => "node_exporter-${var.node_exporter_version}.linux-${local.goarch[f.arch]}" }
  arch    = { for name, f in data.conn3x_host.facts : name => local.goarch[f.arch] }
}

circuit "node_exporter" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # Minimal images can lack any of these.
  step "tools" {
    for_each = toset(["curl", "tar", "gzip"])
    package {
      name = item.value
    }
  }

  step "user" {
    user {
      name   = "node_exporter"
      system = true
      home   = "/var/lib/node_exporter"
      shell  = "/usr/sbin/nologin"
    }
  }

  step "download" {
    download {
      url    = "https://github.com/prometheus/node_exporter/releases/download/v${var.node_exporter_version}/${local.release[each.key]}.tar.gz"
      sha256 = var.checksums[local.arch[each.key]]
      dest   = "/opt/node_exporter/${local.release[each.key]}.tar.gz"
    }
  }

  step "unpack" {
    archive {
      src     = "/opt/node_exporter/${local.release[each.key]}.tar.gz"
      dest    = "/opt/node_exporter"
      creates = "/opt/node_exporter/${local.release[each.key]}/node_exporter"
    }
  }

  step "unit" {
    file {
      path    = "/etc/systemd/system/node_exporter.service"
      content = <<-EOT
        [Unit]
        Description=Prometheus node_exporter
        After=network-online.target
        Wants=network-online.target

        [Service]
        User=node_exporter
        Group=node_exporter
        ExecStart=${join(" ", concat(["/opt/node_exporter/${local.release[each.key]}/node_exporter", "--web.listen-address=:${var.listen_port}"], var.extra_args))}
        Restart=on-failure
        NoNewPrivileges=true
        ProtectSystem=strict
        ProtectHome=true

        [Install]
        WantedBy=multi-user.target
      EOT
    }
    notify = [handler.restart]
  }

  step "running" {
    service {
      name    = "node_exporter"
      state   = "started"
      enabled = true
    }
  }

  handler "restart" {
    service {
      name = "node_exporter"
    }
  }
}
