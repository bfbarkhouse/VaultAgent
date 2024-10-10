
#!/bin/bash

#===README===
#Run this script with sudo
#Upload Vault TLS listener cert to /opt/vault/tls/vault_tls_listener_bundle.pem
#Upload agent-config.hcl to /etc/vault.d/ and modify for your specific values
#Upload vault.service to /etc/vault.d/

set -euxo pipefail
VAULT_ADDR="<Vault server address>"
VAULT_NAMESPACE="<Vault namespace>"
VAULT_ACME_CA_PATH="<pki mount path>"
EC2_PUBLIC_DNS="$(curl http://169.254.169.254/latest/meta-data/public-hostname)"
VAULT_AGENT_GROUP="vault"
VAULT_ACME_PKI_ROLE="<rolename>"
LINUX_DISTRO="<ubuntu,debian,centos,rhel,fedora,amazon>"

#Remove any pre-installed certbot packages
if [$LINUX_DISTRO == "ubuntu" -o $LINUX_DISTRO == "debian"]
then
    apt-get remove certbot
elif [$LINUX_DISTRO == "centos" -o $LINUX_DISTRO == "rhel" -o $LINUX_DISTRO == "amazon"]
then
    yum remove certbot
elif [$LINUX_DISTRO == "fedora"]
then
    dnf remove certbot
else
    do exit
fi

#Install certbot
snap install --classic certbot

#Install Vault
if [$LINUX_DISTRO == "ubuntu" -o $LINUX_DISTRO == "debian"]
then
    apt update && sudo apt install gpg wget
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt update && apt install vault
elif [$LINUX_DISTRO == "centos" -o $LINUX_DISTRO == "rhel"]
then
    yum install -y yum-utils
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    yum -y install vault
elif [$LINUX_DISTRO == "fedora"]
then
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
    dnf -y install vault
elif [$LINUX_DISTRO == amazon]
then
    yum install -y yum-utils
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    yum -y install vault
else
    do exit
fi

#Get the ACME server’s issuer CA cert:
curl $VAULT_ADDR/v1/p$VAULT_ACME_CA_PATH/ca/pem -o /opt/vault/tls/acme_ca.pem
#Tell certbot to trust the CA. Certbot uses the requests library, which does not use the operating system trusted root store.
export REQUESTS_CA_BUNDLE="/opt/vault/tls/acme_ca.pem"
#Need to set this var globally for renewals to work. override certbot's systemd?

certbot certonly --standalone --server $VAULT_ADDR/v1/$VAULT_NAMESPACE/$VAULT_ACME_CA_PATH/roles/$VAULT_ACME_PKI_ROLE/acme/directory -d $EC2_PUBLIC_DNS --key-type rsa --register-unsafely-without-email

#Modify certificate permissions
chmod 0755 /etc/letsencrypt/{live,archive} #Allows any user to read/execute and owner to read/write/execute the folder
chown root:$VAULT_AGENT_GROUP /etc/letsencrypt/live/$EC2_PUBLIC_DNS/privkey.pem #changes owner to root and group to the vault group
chmod 0640 /etc/letsencrypt/live/$EC2_PUBLIC_DNS/privkey.pem #Allows the owner to read/write and group to read the private key

#Inspect cert:
#sudo openssl x509 -in /etc/letsencrypt/live/$EC2_PUBLIC_DNS/cert.pem -text

#Check cerbot certs its managing:
#sudo certbot certificates

#Check cerbot scheduled monitoring task:
#systemctl list-timers

#Register and start the Vault Agent service
mv /etc/vault.d/vault.service /usr/lib/systemd/system
systemctl enable vault.service
systemctl start vault.service

