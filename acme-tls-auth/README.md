# Automatic secure introduction (secret zero) of HashiCorp Vault clients without platform identity

This folder contains code to automate a secure introduction (secret zero) pattern to authenticate to HashiCorp Vault when there isn't an alternative trusted platform identity, such as a VMware vSphere environment. The secret zero used to authenticate to Vault is a TLS client certificate issued by Vault's PKI Engine configured as an Automated Certificate Management Environment (ACME) server. The ACME protocol leverages DNS as the root of trust and clients must satisfy a validation challenge in order to obtain a certificate. 

In pattern demonstrated, a ACME client (cerbot) requests a certificate from a Vault PKI Certificate Authority. The ACME protocol validates the request and then Vault issues a short-lived certiticate back to the client machine. From there, Vault Agent presents the certicate back to Vault's TLS cert auth method for autnetication and authorization. The certificate's DNS SANs are matched to the TLS auth method role and if allowed, Vault returns the client token (containing its ACL policies). Vault Agent logs into Vault with the token to retrieve and render the desired secrets.

A flow such as this provides an automated way to solve the secure introduction problem with a secret zero that is unique to the client, has a configurable TTL and is automatically renewed without manual intervention. Further, by using Vault Agent, the lifecycles of the Vault token and secrets are fully managed transparently to any application running on the machine.

Full blog post coming soon.

> [Credit to this blog post for inspiration](https://adfinis.com/en/blog/secret-zero-with-acme/).

## Guide

### Configure Vault
Terraform is used to configure Vault's PKI secrets engine with a root CA and intermediate CA. The intermediate CA serves as the ACME server endpoint. The intermediate CA has a role which issues signed certificates with ClientAuth extended key usage. There really only needs to be a single role to issue client certificates since the ACME protocol will handle the DNS validation and authorization that proves the client is entitled to the certificate.

Vault's TLS Auth Method is also configured with a role. This role trusts client certificates signed by Vault's intermediate CA. Authorization is controlled by allowed_dns_sans and sets its token ACL policies. This example configures one role, but additional roles should be configured when different policies or different sets of allows DNS SANs are required.

Create a file called variables.tfvars and declare your values

```bash
export VAULT_TOKEN=...
terraform apply -var-file=variables.tfvars
```

### Configure VM