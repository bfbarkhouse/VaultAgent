output "vault_tls_listener_bundle" {
  value = local.vault_tls_listener_bundle
}
output "ca_cert_message" {
  value = "Save Vault's TLS listener cert to a PEM file using 'terraform output -raw vault_tls_listener_bundle > vault_tls_listener_bundle.pem'\nThen upload to the client filesystem and set ca_cert to its path in the Vault Agent config."
}