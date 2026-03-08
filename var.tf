variable "do_token" {
  type      = string
  sensitive = true
}

variable "letsencrypt_email" {
  type        = string
  description = "Email address for Let's Encrypt certificate notifications"
}
