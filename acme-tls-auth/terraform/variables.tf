variable "vault_server" {
  type    = string
  default = "http://127.0.0.1:8200"
}
variable "vault_ns" {
  type    = string
  default = "root"
}
variable "root_ca_path" {
  type    = string
  default = "pki_root"

}
variable "root_ca_type" {
  type    = string
  default = "internal"
}
variable "root_ca_cn" {
  type    = string
  default = "vault.internal"
}
variable "root_ca_issuer_name" {
  type    = string
  default = "root-2024-2025"
}
variable "root_ca_role_name" {
  type    = string
  default = "servers"
}
variable "int_ca_path" {
  type    = string
  default = "pki_int"
}
variable "int_ca_type" {
  type    = string
  default = "internal"
}
variable "int_ca_cn" {
  type    = string
  default = "vault.internal Intermediate Authority"
}
variable "int_ca_clientauth_role_name" {
  type    = string
  default = "clientauth"
}
variable "cert_auth_path" {
    type = string
    default = "cert"
}
variable "cert_auth_role_name" {
    type = string
    default = "vaclient"
  
}
variable "cert_auth_allowed_dns_sans" {
    type = list(string)
    default = ["localhost"]
}
variable "cert_auth_policies" {
  type = list(string)
  default = ["default"]
}