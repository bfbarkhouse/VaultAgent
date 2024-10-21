pid_file = "/tmp/pidfile"

#Modify these values before running
vault {
  address = "<Vault server address>"
  namespace = "<Vault namespace>" 
  ca_cert = "/opt/vault/tls/vault_tls_listener.pem"
  client_cert = "/etc/letsencrypt/live/<EC2_PUBLIC_DNS>/fullchain.pem"
  client_key = "/etc/letsencrypt/live/<EC2_PUBLIC_DNS>/privkey.pem"
}

auto_auth {
  method "cert" {
   mount_path = "auth/cert" 
   config = {
      name = "vaclient"
      reload=true
    }
  }

    sink "file" {
    #the written token will be response-wrapped by the sink. 
    wrap_ttl = "10m"
    config = {
      path = "/tmp/wrapped-vault-token"
      #mode = ""
      #A string containing an octal number representing the bit pattern for the file mode, 
      #similar to chmod. Set to 0000 to prevent Vault from modifying the file mode.
    }
  }
}

listener "tcp" {
  address = "0.0.0.0:8100" 
  tls_disable = true  
}

template_config {
  exit_on_retry_failure = true
  static_secret_render_interval = "5m"
  max_connections_per_host = 10
}

template {
  contents     = "{{ with secret \"kv/app1\" }}{{ .Data.data.application_secret }}{{ end }}"
  destination  = "/opt/vault/secrets/application-secret.txt"
  perms = "0640"
  # perms is the permission to render the file. If this option is left
  # unspecified, Consul Template will attempt to match the permissions of the
  # file that already exists at the destination path. If no file exists at that
  # path, the permissions are 0644.
  #user = ""
  #group = ""
  # User and group ownerships of the rendered file. They can be specified
  # in the form of username/group name or UID/GID. If left unspecified, Consul Template
  # will preserve the ownerships of the existing file. If no file exists, the
  # ownerships will default to the user running Consul Template. This option is not
  # supported on Windows.
  #exec {
    #command = ["restart", "service", "foo"]
    #timeout = "30s"
  #} 
  #The exec block executes a command when the template is rendered and the output has changed. 
  #The block parameters are command (string or array: required) and timeout (string: optional, defaults to 30s). 
  #command can be given as a string or array of strings to execute, such as "touch myfile" or ["touch", "myfile"]. 
  #To protect against command injection, we strongly recommend using an array of strings, and we attempt to parse that way first. 
  #Note also that using a comma with the string approach will cause it to be interpreted as an array, which may not be desirable.
}
