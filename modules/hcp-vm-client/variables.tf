variable "resource_group" {
  type        = string
  description = "The resource group the resource will be created in"
}

variable "location" {
  type        = string
  description = "Where the vm will be created"
}

variable "subnet_id" {
  type        = string
  description = "The subnet ID to create VM consul clients in"
}

variable "allowed_ssh_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the vm Instances will allow SSH connections"
  type        = list(string)
  default     = []
}

variable "allowed_http_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the vm Instances will allow connections over 8080"
  type        = list(string)
  default     = []
}

variable "client_config_file" {
  type        = string
  description = "The client config file provided by HCP"
}

variable "client_ca_file" {
  type        = string
  description = "The Consul client CA file provided by HCP"
}

variable "root_token" {
  type        = string
  description = "The Consul Secret ID of the Consul root token"
}

variable "consul_version" {
  type        = string
  description = "The Consul version of the HCP servers"
}

variable "nsg_name" {
  type        = string
  description = "Network security group name that ssh/http cidrs will be added to"
}

variable "prefix" {
  type        = string
  description = "Add a prefix to all resoures in module for uniqueness"
  default     = "vmclient"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR defaulted to the CIDR used throughtout this repo for customer vnets"
  default     = "10.0.0.0/8"
}
