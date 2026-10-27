output "metrics_urls" {
  description = "Each host's metrics URL, by host name."
  value       = { for name, h in var.hosts : name => "http://${try(h.address, h)}:${var.listen_port}/metrics" }
}
