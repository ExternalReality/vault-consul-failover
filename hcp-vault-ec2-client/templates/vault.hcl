cluster_addr  = "https://<LOCAL_IPV4_ADDRESS>:8201"
api_addr      = "https://<LOCAL_IPV4_ADDRESS>:8200"

listener "tcp" {
  address            = "0.0.0.0:8200"
  tls_cert_file      = "/opt/vault/tls/vault-cert.pem"
  tls_key_file       = "/opt/vault/tls/vault-key.pem"
  tls_client_ca_file = "/opt/vault/tls/vault-ca.pem"
}

storage "raft" {
  path    = "/var/raft/"
  node_id = "node"
}