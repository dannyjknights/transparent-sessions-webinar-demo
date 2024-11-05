resource "vault_mount" "pki_int" {
  path                      = "pki_int"
  type                      = "pki"
  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = 157680000
}

resource "vault_pki_secret_backend_intermediate_cert_request" "csr_request" {
  backend     = vault_mount.pki_int.path
  type        = "internal"
  common_name = "transparentsessions.com Intermediate Authority"
}

resource "local_file" "csr_request_cert" {
  content  = vault_pki_secret_backend_intermediate_cert_request.csr_request.csr
  filename = "pki_intermediate.csr"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate" {
  backend     = vault_mount.pki_root.path
  common_name = "transparentsessions.com"
  csr         = vault_pki_secret_backend_intermediate_cert_request.csr_request.csr
  format      = "pem_bundle"
  ttl         = 15480000
  issuer_ref  = vault_pki_secret_backend_root_cert.pki_root_cert.issuer_id
}

resource "local_file" "intermediate_ca_cert" {
  content  = vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate
  filename = "intermediate.cert.pem"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  backend     = vault_mount.pki_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate
}

resource "vault_pki_secret_backend_issuer" "intermediate" {
  backend     = vault_mount.pki_int.path
  issuer_ref  = vault_pki_secret_backend_intermediate_set_signed.intermediate.imported_issuers[0]
  issuer_name = "transparentsessions-dot-com-intermediate"
}

resource "vault_pki_secret_backend_role" "intermediate_role" {
  backend          = vault_mount.pki_int.path
  issuer_ref       = vault_pki_secret_backend_issuer.intermediate.issuer_ref
  name             = "transparentsessions-dot-com"
  ttl              = 86400
  max_ttl          = 2592000
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["transparentsessions.com"]
  allow_subdomains = true
}