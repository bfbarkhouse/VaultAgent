#!/bin/bash

#===README===
#Run this script with sudo
#Upload agent-config.hcl to directory where running this script
#Upload vault.service to directory where running this script
scp -i vault-acme-demo.pem ~/Documents/Code/VaultAgent/acme-tls-auth/ec2-client-config.sh ubuntu@ec2-54-190-178-231.us-west-2.compute.amazonaws.com:/home/ubuntu/ec2-client-config.sh

set -eux
VAULT_ADDR="<Vault server address>"
VAULT_NAMESPACE="<Vault namespace>"
VAULT_ACME_CA_PATH="<pki mount path>"
EC2_PUBLIC_DNS="$(curl http://169.254.169.254/latest/meta-data/public-hostname)"
VAULT_AGENT_GROUP="vault"
VAULT_ACME_PKI_ROLE="<rolename>"
LINUX_DISTRO="<ubuntu,debian,centos,rhel,fedora,amazon>"

mkdir -p /opt/vault/tls
mkdir -p /etc/vault.d
mkdir -p /opt/vault/secrets
chgrp -R vault /opt/vault/secrets
sudo chmod 0770 /opt/vault/secrets

cp agent-config.hcl /etc/vault.d
cp vault.service /etc/vault.d

#Remove any pre-installed certbot packages
if [[ "$LINUX_DISTRO" == "ubuntu" || "$LINUX_DISTRO" == "debian" ]]
then
    apt-get remove certbot
elif [[ "$LINUX_DISTRO" == "centos" || "$LINUX_DISTRO" == "rhel" || "$LINUX_DISTRO" == "amazon" ]]
then
    yum remove certbot
elif [[ "$LINUX_DISTRO" == "fedora" ]]
then
    dnf remove certbot
else
    echo "Please set a valid Linux distro"
    exit 1
fi

#Install certbot
snap install --classic certbot

#Install Vault
#Add a check if Vault is already installed
if [[ "$(vault -v)" ]]
then
    echo "Vault is already installed."
elif [[ "$LINUX_DISTRO" == "ubuntu" || "$LINUX_DISTRO" == "debian" ]]
then
    apt update && sudo apt install gpg wget
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt update && apt install vault
elif [[ $LINUX_DISTRO == "centos" || $LINUX_DISTRO == "rhel" ]]
then
    yum install -y yum-utils
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    yum -y install vault
elif [[ "$LINUX_DISTRO" == "fedora" ]]
then
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
    dnf -y install vault
elif [[ "$LINUX_DISTRO" == amazon ]]
then
    yum install -y yum-utils
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    yum -y install vault
else
    echo "Please set a valid Linux distro"
    exit 1
fi

#Strip https:// from VAULT_ADDR
VAULT_ADDR_STRIPPED=${VAULT_ADDR#*//}
#Get the Vault server's TLS listener certificate
openssl s_client -showcerts -connect $VAULT_ADDR_STRIPPED </dev/null 2>/dev/null|openssl x509 -outform PEM >/opt/vault/tls/vault_tls_listener.pem

#If certbot does not trust this cert, uncomment the following line
#export REQUESTS_CA_BUNDLE=/opt/vault/tls/vault_tls_listener.pem

#Request the client certificate from Vault PKI ACME server
#When using self-signed Vault TLS listener cert append ----no-verify-ssl
#IF EAB required append --eab-kid <key id> --eab-hmac-key <key>
certbot certonly --standalone --server $VAULT_ADDR/v1/$VAULT_NAMESPACE/$VAULT_ACME_CA_PATH/roles/$VAULT_ACME_PKI_ROLE/acme/directory -d $EC2_PUBLIC_DNS --key-type rsa --register-unsafely-without-email

#Modify certificate permissions
chmod 0755 /etc/letsencrypt/{live,archive} #Allows any user to read/execute and owner to read/write/execute the folder
chgrp -h $VAULT_AGENT_GROUP /etc/letsencrypt/live/$EC2_PUBLIC_DNS/privkey.pem
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

