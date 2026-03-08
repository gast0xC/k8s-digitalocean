variable "cluster_name" {
  type        = string
  description = "Name of the DigitalOcean Kubernetes cluster"
  default     = "my-cluster"
}

variable "region" {
  type        = string
  description = "DigitalOcean region (e.g. nyc3, fra1, ams3)"
  default     = "nyc3"
}
