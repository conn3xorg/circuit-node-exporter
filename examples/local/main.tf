variable "port" {
  type    = number
  default = 2222
}

# CI sets these to install an older node_exporter first, then upgrades to
# the circuit's own pin by applying again without them.
variable "node_exporter_version" {
  type    = string
  default = null
}

variable "checksums" {
  type    = map(string)
  default = null
}

module "node_exporter" {
  source = "../.."

  hosts                 = { box = "127.0.0.1" }
  ssh_port              = var.port
  ssh_private_key_file  = "./id_ed25519"
  ssh_known_hosts_file  = "./known_hosts"
  node_exporter_version = var.node_exporter_version
  checksums             = var.checksums
}

output "metrics_urls" {
  value = module.node_exporter.metrics_urls
}
