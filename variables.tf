variable "do_token" {
  type        = string
  sensitive   = true
  description = "DigitalOcean API token. Set via TF_VAR_do_token env var."
}

variable "letsencrypt_email" {
  type        = string
  description = "Email for Let's Encrypt account. Receives cert expiry warnings."
}
