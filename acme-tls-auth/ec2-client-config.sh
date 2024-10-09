
#!/bin/bash
#===README===
#Install certbot
#Install Vault Agent

set -euxo pipefail
VAULT_ADDR="<Vault server address>"
VAULT_NAMESPACE="<Vault namespace>"
VAULT_ACME_CA_PATH="<pki mount path>"
EC2_PUBLIC_DNS="$(curl http://169.254.169.254/latest/meta-data/public-hostname)"
VAULT_AGENT_GROUP="<group>"
VAULT_ACME_PKI_ROLE="<rolename>"

#Get the ACME server’s issuer CA cert:
curl $VAULT_ADDR/v1/p$VAULT_ACME_CA_PATH/ca/pem -o /etc/vault/certs/acme_ca.pem
#Tell certbot to trust the CA
export REQUESTS_CA_BUNDLE="/etc/vault/certs/acme_ca.pem"

sudo certbot certonly --standalone --server $VAULT_ADDR/v1/$VAULT_NAMESPACE/$VAULT_ACME_CA_PATH/roles/$VAULT_ACME_PKI_ROLE/acme/directory -d $EC2_PUBLIC_DNS --key-type rsa --register-unsafely-without-email
sudo chmod 0755 /etc/letsencrypt/{live,archive}
sudo chgrp $VAULT_AGENT_GROUP /etc/letsencrypt/live/$EC2_PUBLIC_DNS/privkey.pem
sudo chmod 0640 /etc/letsencrypt/live/$EC2_PUBLIC_DNS/privkey.pem

#Inspect cert:
#sudo openssl x509 -in /etc/letsencrypt/live/$EC2_PUBLIC_DNS/cert.pem -text

#Check cerbot certs its managing:
#sudo certbot certificates

#Check cerbot scheduled monitoring task:
#systemctl list-timers

#Upload Vault TLS listener cert to /etc/vault/certs/vault_tls_cert.pem
#Upload agent-config.hcl to /etc/vault/config and modify for your specific values
#Start the Vault Agent
vault agent -config-file=/etc/vault/config/agent-config.hcl -log-file=/var/logs/vault-agent.log


