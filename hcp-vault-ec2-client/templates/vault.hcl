ui = true

#mlock = true
disable_mlock = true

storage "raft" {
  path = "/opt/vault/data/raft"
  node_id = "raft_node_1"
}

service_registration "consul" {
  address = "127.0.0.1:8500"
  token   = "${CONSUL_ACL_TOKEN}"
}

cluster_addr = "http://127.0.0.1:8201"
api_addr = "http://127.0.0.1:8200"

# HTTP listener
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable = 1
#  tls_cert_file = "/opt/vault/tls/tls.crt"
#  tls_key_file  = "/opt/vault/tls/tls.key"
}

# Enterprise license_path
# This will be required for enterprise as of v1.8
#license_path = "/etc/vault.d/vault.hclic"

# Example AWS KMS auto unseal
#seal "awskms" {
#  region = "us-east-1"
#  kms_key_id = "REPLACE-ME"
#}