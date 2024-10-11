# Automatic secure introduction (secret zero) of HashiCorp Vault without platform identity

This folder contains code to automate a secure introduction (secret zero) pattern to authenticate to HashiCorp Vault when there isn't an alternative trusted platform identity, such as a VMware vSphere environment. The secret zero used to authenticate to Vault is a TLS client certificate issued by Vault's PKI Engine configured as an Automated Certificate Management Environment (ACME) server. The ACME protocol leverages DNS as the root of trust and clients must satisfy a validation challenge in order to obtain a certificate. 

In pattern demonstrated, a ACME client (cerbot) requests a certificate from a Vault PKI Certificate Authority. The ACME protocol validates the request and then Vault issues a short-lived certiticate back to the client machine. From there, Vault Agent presents the certicate back to Vault's TLS cert auth method for autnetication and authorization. The certificate's DNS SANs are matched to the TLS auth method role and if allowed, Vault returns the client token (containing its ACL policies). Vault Agent logs into Vault with the token to retrieve and render the desired secrets.

A flow such as this provides an automated way to solve the secure introduction problem with a secret zero that is unique to the client, has a configurable TTL and is automatically renewed without manual intervention. Further, by using Vault Agent, the lifecycles of the Vault token and secrets are fully managed transparently to any application running on the machine.

Full blog post coming soon.

> [Credit to this blog post for inspiration](https://adfinis.com/en/blog/secret-zero-with-acme/).

## Guide

###Configure Vault

###Configure VM