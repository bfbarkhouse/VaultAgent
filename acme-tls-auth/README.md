# Automatic secure introduction (secret zero) of HashiCorp Vault clients without platform identity

This folder contains code to automate a [secure introduction/secret zero](https://developer.hashicorp.com/vault/tutorials/app-integration/secure-introduction) pattern to authenticate to HashiCorp Vault without platform identity integration or trusted orchestrator. This is useful in an environment such as an on-premise VMware vSphere environment. The secret zero used to authenticate to Vault is a TLS client certificate issued by Vault's [PKI Engine](https://developer.hashicorp.com/vault/docs/secrets/pki) configured as an [Automated Certificate Management Environment](https://www.hashicorp.com/blog/what-is-acme-pki) (ACME) server. The ACME protocol leverages DNS as the root of trust and clients must satisfy a [validation challenge](https://letsencrypt.org/docs/challenge-types/) in order to obtain a certificate. 

NOTE: For convenience, an AWS EC2 Linux instance was used to model this pattern. However, the ec2-client-config.sh script can easily be adapted to other environments. Vault's [AWS auth method](https://developer.hashicorp.com/vault/docs/auth/aws) is recommended in real-world EC2 deployments.

In the pattern demonstrated, an ACME client [(certbot)](https://certbot.eff.org/) requests a certificate from a Vault PKI Certificate Authority. The ACME protocol validates the request and then Vault issues a short-lived certiticate back to the client machine. From there, [Vault Agent](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent) presents the certificate back to Vault's [TLS cert auth method](https://developer.hashicorp.com/vault/docs/auth/cert) for authentication and authorization. The certificate's DNS SANs are matched to the TLS auth method role and if allowed, Vault returns the client token (containing its ACL policies). Vault Agent logs into Vault with the token to retrieve and render the desired secrets.

A flow such as this provides an automated way to solve the secure introduction problem with a secret zero that is unique to the client, has a configurable TTL and is automatically renewed without manual intervention. Further, by using Vault Agent, the lifecycles of the Vault token and secrets are fully managed transparently to any application running on the machine.

Full blog post coming soon.

This is a visualization of the VM provisioning flow, using VMware vSphere as an example target platform without inherent identity:

![Vault Secure Intro  - acme stage](https://github.com/user-attachments/assets/9b573442-ef05-4beb-8291-45b2c474d96e)

This is a visualization of the VM runtime flow:

![Vault Secure Intro  - acme run](https://github.com/user-attachments/assets/ec151ecd-4864-4a9e-8576-3ca86dc0ab57)


> [Credit to this blog post for inspiration](https://adfinis.com/en/blog/secret-zero-with-acme/).

## Usage

### Configure Vault
Terraform is used to configure Vault's PKI secrets engine with a root CA and intermediate CA. The intermediate CA serves as the ACME server endpoint. The intermediate CA has a role which issues signed certificates with ClientAuth extended key usage. There really only needs to be a single role to issue client certificates since the ACME protocol will handle the DNS validation and authorization of the client.

Vault's TLS Auth Method is also configured with a role. This role trusts client certificates signed by Vault's intermediate CA. Authorization is controlled by [allowed_dns_sans](https://developer.hashicorp.com/vault/api-docs/auth/cert#allowed_dns_sans) and sets its token ACL policies. This example configures one role, but additional roles should be configured when different policies or different sets of allows DNS SANs are required.

#### 1. Create a file called variables.tfvars and declare your values

#### 2. Apply the Terraform

```bash
export VAULT_TOKEN=...
terraform apply -var-file=variables.tfvars
```
### Configure VM
This assumes you have an AWS EC2 Linux instance available and started with the following prerequisites:
* The instance has a Public DNS (IPv4) hostname. 
* The instance has its metadata service enabled. 
* The attached Security Group allows Vault to connect to port 80 on the target instance (for the http-01 challenge). 

> Details on ACME challenge types and custom DNS resolution can be found [here.](https://developer.hashicorp.com/vault/api-docs/v1.17.x/secret/pki#acme-challenge-types)

#### 1. 
Edit ec2-client-config.sh and set the following variables:

```bash
VAULT_ADDR="<Vault server address>"
VAULT_NAMESPACE="<Vault namespace>"
VAULT_ACME_CA_PATH="<pki mount path eg. pki_int>"
VAULT_ACME_PKI_ROLE="<rolename eg. clientauth>"
LINUX_DISTRO="<ubuntu,debian,centos,rhel,fedora,amazon>"
```

#### 2. 
Edit agent-config.hcl and set the following values:
```hcl
  address = "<Vault server address>"
  namespace = "<Vault namespace>" 
  client_cert = "/etc/letsencrypt/live/<EC2_PUBLIC_DNS>/fullchain.pem"
  client_key = "/etc/letsencrypt/live/<EC2_PUBLIC_DNS>/privkey.pem"
  ```
#### 3. 
  Edit the template{ contents = ... } value in agent-config.hcl to point to a valid secrets engine path that the TLS auth method role has ACL policy to read.

#### 4. 
Upload the following files:

```bash
scp -i <PATH_TO_LOCAL_PRIVATE_SSH_KEY> ec2-client-config.sh <SERVER_USER@SERVER_IP_ADDRESS>:~
scp -i <PATH_TO_LOCAL_PRIVATE_SSH_KEY> agent-config.hcl <SERVER_USER@SERVER_IP_ADDRESS>:~
scp -i <PATH_TO_LOCAL_PRIVATE_SSH_KEY> vault.service <SERVER_USER@SERVER_IP_ADDRESS>:~
```

#### 5. 
SSH into the instance and execute the script:

```bash
ssh -i <PATH_TO_LOCAL_PRIVATE_SSH_KEY> <SERVER_USER@SERVER_IP_ADDRESS>
sudo chmod +x ec2-client-config.sh
sudo ./ec2-client-config.sh
```
View certbot managed certificates:

```bash
sudo certbot certificates
```

Confirm cerbot registered a renewal timer:

```bash
systemctl list-timers
```
View Vault Agent logs:

```bash
journalctl -b --no-pager -u vault
```

