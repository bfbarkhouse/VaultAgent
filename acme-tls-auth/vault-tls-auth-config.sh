#!/bin/bash

set -euxo pipefail
export VAULT_ADDR=<Vault server address>
export VAULT_NAMESPACE=<namespace>
export EC2_PUBLIC_DNS=<dns>

#Get the ACME server’s issuer CA cert:
curl $VAULT_ADDR/v1/pki_int/ca/pem -o pki_int_ca.pem

vault auth enable cert
vault write auth/cert/certs/vaclient display_name=vaclient policies=default,vault-agent certificate=@pki_int_ca.pem allowed_dns_sans=$EC2_PUBLIC_DNS ttl=3600
