output "vps_ip" {
  description = "Public IPv4 address of the VPS."
  value       = digitalocean_droplet.web.ipv4_address
}

output "vps_id" {
  description = "DigitalOcean droplet ID."
  value       = digitalocean_droplet.web.id
}

output "ssh_fingerprint" {
  description = "Fingerprint of the uploaded SSH public key."
  value       = digitalocean_ssh_key.vision_devops.fingerprint
}
