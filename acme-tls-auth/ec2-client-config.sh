
#!/bin/bash

set -euxo pipefail
export VAULT_ADDR=<Vault server address>
export VAULT_NAMESPACE=<namespace>
export EC2_PUBLIC_DNS=$(curl http://169.254.169.254/latest/meta-data/public-hostname)
export VAULT_AGENT_GROUP=<group>

#Install certbot
#Install Vault Agent

sudo certbot certonly --standalone --server $VAULT_ADDR/v1/$VAULT_NAMESPACE/pki_int/roles/clientauth/acme/directory -d $EC2_PUBLIC_DNS --key-type rsa --register-unsafely-without-email
sudo chmod 0755 /etc/letsencrypt/{live,archive}
sudo chgrp $VAULT_AGENT_GROUP /etc/letsencrypt/live/$EC2_PUBLIC_DNS/privkey.pem
sudo chmod 0640 /etc/letsencrypt/live/$EC2_PUBLIC_DNS/privkey.pem

#Inspect cert:
#sudo openssl x509 -in /etc/letsencrypt/live/$EC2_PUBLIC_DNS/cert.pem -text

#Check cerbot certs its managing:
#sudo certbot certificates

#Check cerbot scheduled monitoring task:
#systemctl list-timers

#Get the ACME server’s issuer CA cert:
curl $VAULT_ADDR/v1/pki_int/ca/pem -o /etc/vault.d/CA/pki_int_ca.pem

#Upload Vault TLS listener cert to /etc/vault.d/CA/vault_tls_cert.pem

vault agent -config-file=/etc/vault.d/agent/agent-config.hcl -log-file=/var/logs/vault-agent.log


