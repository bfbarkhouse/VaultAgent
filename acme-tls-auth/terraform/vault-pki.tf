#Set up the root CA PKI mount
resource "vault_mount" "pki_root" {
  path                  = var.root_ca_path
  type                  = "pki"
  description           = "This is the root pki mount"
  max_lease_ttl_seconds = 315360000
}
resource "vault_pki_secret_backend_root_cert" "root_ca_cert" {
  depends_on         = [vault_mount.pki_root]
  backend            = vault_mount.pki_root.path
  type               = var.root_ca_type
  common_name        = var.root_ca_cn
  issuer_name        = var.root_ca_issuer_name
  ttl                = "315360000"
  format             = "pem"
  private_key_format = "der"
  key_type           = "rsa"
  key_bits           = 4096
  #exclude_cn_from_sans  = true
}
resource "vault_pki_secret_backend_config_cluster" "root_pki_cluster_config" {
  backend  = vault_mount.pki_root.path
  path     = "${var.vault_server}/v1/${var.root_ca_path}"
  aia_path = "${var.vault_server}/v1/${var.root_ca_path}t"
}
resource "vault_pki_secret_backend_role" "server_role" {
  backend         = vault_mount.pki_root.path
  name            = var.root_ca_role_name
  allowed_domains = ["*"]
  no_store        = false
}
resource "vault_pki_secret_backend_config_urls" "root_pki_config_urls" {
  backend                 = vault_mount.pki_root.path
  issuing_certificates    = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/der"]
  crl_distribution_points = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der"]
  ocsp_servers            = ["{{cluster_path}}/ocsp"]
  enable_templating       = true
}

#Set up the intermediate CA PKI mount
resource "vault_mount" "pki_int" {
  path                        = var.int_ca_path
  type                        = "pki"
  description                 = "This is the intermediate pki mount"
  max_lease_ttl_seconds       = 157680000
  passthrough_request_headers = ["If-Modified-Since"]
  allowed_response_headers    = ["Last-Modified", "Location", "Replay-Nonce", "Link"]
}
resource "vault_pki_secret_backend_intermediate_cert_request" "int_pki_csr" {
  depends_on  = [vault_mount.pki_int]
  backend     = vault_mount.pki_int.path
  type        = var.int_ca_type
  common_name = var.int_ca_cn
}
resource "vault_pki_secret_backend_root_sign_intermediate" "root_sign_int_csr" {
  depends_on  = [vault_pki_secret_backend_intermediate_cert_request.int_pki_csr]
  backend     = vault_mount.pki_root.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.int_pki_csr.csr
  common_name = var.int_ca_cn
  format      = "pem_bundle"
  ttl         = 157680000
}
resource "vault_pki_secret_backend_intermediate_set_signed" "int_pki_set_signed" {
  backend     = vault_mount.pki_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.root_sign_int_csr.certificate
}
resource "vault_pki_secret_backend_config_cluster" "int_pki_cluster_config" {
  backend  = vault_mount.pki_int.path
  path     = "${var.vault_server}/v1/${var.int_ca_path}"
  aia_path = "${var.vault_server}/v1/${var.int_ca_path}"
}
resource "vault_pki_secret_backend_config_urls" "int_pki_config_urls" {
  backend                 = vault_mount.pki_int.path
  issuing_certificates    = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/der"]
  crl_distribution_points = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der"]
  ocsp_servers            = ["{{cluster_path}}/ocsp"]
  enable_templating       = true
}
resource "vault_generic_endpoint" "int_pki_acme_config" {
  depends_on           = [vault_mount.pki_int]
  path                 = "${vault_mount.pki_int.path}/config/acme"
  ignore_absent_fields = true
  data_json            = <<EOT
    {
        "enabled" : "true",
        "allow_role_ext_key_usage" : "true" 
    }
    EOT
}

#Create the PKI role to issue TLS client certs.
resource "vault_pki_secret_backend_role" "int_pki_client_auth_role" {
  backend        = vault_mount.pki_int.path
  name           = var.int_ca_clientauth_role_name
  ttl            = 2592000
  max_ttl        = 2592000
  #Any name is allowed since ACME will not issue a cert if the DNS challenge fails
  allow_any_name = true
  no_store       = false
  ext_key_usage  = ["ClientAuth"]
}

#Set up TLS auth method
resource "vault_auth_backend" "cert" {
    path = var.cert_auth_path
    type = "cert"
}

resource "vault_cert_auth_backend_role" "vault_agent_cert_auth_role" {
    name           = var.cert_auth_role_name
    certificate    = vault_pki_secret_backend_root_sign_intermediate.root_sign_int_csr.certificate
    backend        = vault_auth_backend.cert.path
    #Prevent authentication if the cert presented does not contain a matching DNS SAN
    allowed_dns_sans = var.cert_auth_allowed_dns_sans
    token_ttl      = 3600
    token_policies = var.cert_auth_policies
}

#Output the TLS listener CA file
data "tls_certificate" "vault_tls_listener_cert" {
    url = "https://bbarkhouse-vault-cluster.vault.ccaa60c2-b32a-48c6-a722-261bab55cd7c.aws.hashicorp.cloud:8200"
    #url = var.vault_server
}
locals {
    get_leaf_cert = length(data.tls_certificate.vault_tls_listener_cert.certificates)
    vault_tls_listener_cert = "${data.tls_certificate.vault_tls_listener_cert.certificates["${local.get_leaf_cert}"-1].cert_pem}"

}

