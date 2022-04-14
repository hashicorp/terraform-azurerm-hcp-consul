
variable "network_region" {
  type        = string
  description = "the network region"
  default     = "West US 2"
}

variable "hvn_region" {
  type        = string
  description = "the hvn region"
  default     = "westus2"
}

variable "hvn_id" {
  type        = string
  description = "the hvn id"
  default     = "hvn-foobar"
}

variable "cluster_id" {
  type        = string
  description = "The cluster id is unique. All other unique values will be derived from this (resource group, vnet etc)"
  default     = "hcp-azure"
}

variable "consul_tier" {
  type        = string
  description = "The HCP Consul tier to use when creating a Consul cluster"
  default     = "development"
}

variable "vnet_cidrs" {
  type        = list(string)
  description = "The ciders of the vnet. This should make sense with vnet_subnets"
  default     = ["10.0.0.0/16"]
}

variable "vnet_subnets" {
  type        = map(string)
  description = "The subnets associated with the vnet"
  default = {
    "subnet1" = "10.0.1.0/24",
    "subnet2" = "10.0.2.0/24",
    "subnet3" = "10.0.3.0/24",
  }
}

variable "subscription_id" {
  type        = string
  description = "this is the azure subscription id"
}

variable "tenant_id" {
  type        = string
  description = "this is tenant id"
}

variable "hcp_client_id" {
  description = "HCP Client ID."
  type        = string
  sensitive   = true
}

variable "hcp_client_secret" {
  description = "HCP Client Secret."
  type        = string
  sensitive   = true
}