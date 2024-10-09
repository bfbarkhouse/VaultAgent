#!/bin/bash

set -euxo pipefail
export VAULT_ADDR=<Vault server address>
export VAULT_NAMESPACE=<namespace>

vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki
vault write -field=certificate pki/root/generate/internal \
   common_name="vault.internal" \
   issuer_name="root-2024" \
   ttl=87600h > root_2024_ca.crt
vault write pki/config/cluster \
   path=$VAULT_ADDR/v1/pki \
   aia_path=$VAULT_ADDR/v1/pki
vault write pki/roles/2024-servers \
   allow_any_name=true \
   no_store=false
vault write pki/config/urls \
   issuing_certificates={{cluster_aia_path}}/issuer/{{issuer_id}}/der \
   crl_distribution_points={{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der \
   ocsp_servers={{cluster_path}}/ocsp \
   enable_templating=true
vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int
vault write -format=json pki_int/intermediate/generate/internal \
   common_name="vault.internal Intermediate Authority" \
   issuer_name="vault-intermediate" \
   | jq -r '.data.csr' > pki_intermediate.csr
vault write -format=json pki/root/sign-intermediate \
   issuer_ref="root-2024" \
   csr=@pki_intermediate.csr \
   format=pem_bundle ttl="43800h" \
   | jq -r '.data.certificate' > intermediate.cert.pem
vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem
vault write pki_int/config/cluster \
   path=$VAULT_ADDR/v1/pki_int \
   aia_path=$VAULT_ADDR/v1/pki_int
vault write pki_int/config/urls \
   issuing_certificates={{cluster_aia_path}}/issuer/{{issuer_id}}/der \
   crl_distribution_points={{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der \
   ocsp_servers={{cluster_path}}/ocsp \
   enable_templating=true
vault secrets tune \
      -passthrough-request-headers=If-Modified-Since \
      -allowed-response-headers=Last-Modified \
      -allowed-response-headers=Location \
      -allowed-response-headers=Replay-Nonce \
      -allowed-response-headers=Link \
      pki_int
vault write pki_int/config/acme enabled=true allow_role_ext_key_usage=true
vault write pki_int/roles/clientauth issuer_ref="$(vault read -field=default pki_int/config/issuers)" allow_any_name=true ttl="720h" max_ttl="720h" no_store=false ext_key_usage=ClientAut


