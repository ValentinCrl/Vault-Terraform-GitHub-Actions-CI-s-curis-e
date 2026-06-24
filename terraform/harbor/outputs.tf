output "server_ipv4" {
  description = "IP publique du serveur Harbor — à utiliser pour créer l'enregistrement DNS A."
  value       = hcloud_server.harbor.ipv4_address
}

output "dns_record_to_create" {
  description = "Enregistrement DNS à créer manuellement chez ton registrar avant que Harbor ne s'installe."
  value       = "A    ${var.domain}.    →    ${hcloud_server.harbor.ipv4_address}"
}

output "harbor_url" {
  description = "URL de l'interface Harbor (disponible une fois le DNS propagé et l'installation terminée)."
  value       = "https://${var.domain}"
}

output "ssh_command" {
  description = "Commande pour se connecter au serveur et suivre l'installation."
  value       = "ssh root@${hcloud_server.harbor.ipv4_address}   # puis: tail -f /var/log/harbor-bootstrap.log"
}
