pid_file = "./pidfile"

vault {
  address = "https://bbarkhouse-vault-cluster-prod-public-vault-52d974b0.ccc37cc2.z1.hashicorp.cloud:8200"
}

auto_auth {
  method {
    type      = "approle"

    config = {
      role_id_file_path = "roleid"
      secret_id_file_path = "secretid"
      remove_secret_id_file_after_reading = false
    }
  }

  sink {
    type = "file"
    wrap_ttl = "30m"
    config = {
      path = "token_wrapped"
    }
  }
}

listener "tcp" {
  address = "127.0.0.1:8100"
  tls_disable = true
}

template {
  contents     = "{{ with secret \"secret/bruce\" }}{{ index .Data.data \"secret-identity\" }}{{ end }}"
  destination  = "render-content.txt"
}