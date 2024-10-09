output "vault_tls_listener_cert" {
    value = local.vault_tls_listener_cert
}
output "ca_cert_message" {
  value = "Save Vault's TLS listener cert to a PEM file using 'terraform output -raw vault_tls_listener_cert > vault_tls_cert.pem'\nThen upload to the client filesystem and set ca_cert to its path in the Vault Agent config."
}