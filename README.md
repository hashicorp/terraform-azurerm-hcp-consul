# HCP Consul on Azure Module

Terraform module for connecting a HashiCorp Cloud Platform (HCP) Consul cluster to Azure.

## Usage

This module connects a HashiCorp Virtual Network (HVN) with an Azure VNet, ensuring
that all networking rules are in place to allow a Consul client to communicate
with the HCP Consul servers. The module accomplishes this in by:

1. Create and accept a peering connection between the HVN and VNet
2. Create HVN routes that will direct HCP traffic to the CIDR ranges of the
   subnets.
3. Create Azure ingress rules necessary for HCP Consul to communicate to Consul
   clients.

## Examples

These examples allow you to easily research and demo HCP Consul.

- [hcp-vm-demo](https://github.com/hashicorp/terraform-azurerm-hcp-consul/tree/main/examples/hcp-vm-demo) - Use Azure virtual machines to run Consul clients.

## License

This code is released under the Mozilla Public License 2.0. Please see [LICENSE](https://github.com/hashicorp/terraform-azurerm-hcp-consul/blob/main/LICENSE) for more details.
