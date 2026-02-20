# Copyright IBM Corp. 2022, 2023
# SPDX-License-Identifier: MPL-2.0

output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}
