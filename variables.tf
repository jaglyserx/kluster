# Declare the hcloud_token variable from .tfvars
variable "hcloud_token" {
  sensitive = true
}

variable "location" {
  type    = string
  default = "hel1"
}

