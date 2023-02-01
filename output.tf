# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "nsg" {
  value       = length(var.security_group_names) == 0 ? azurerm_network_security_group.nsg.*.name : var.security_group_names
  description = "Newly created azure nsg if 'security_group_names' was not provided"
}
