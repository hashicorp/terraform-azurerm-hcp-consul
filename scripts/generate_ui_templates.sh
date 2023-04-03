#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


generate_base_terraform () {
  cat examples/hcp-$1-demo/{providers,main,output}.tf \
    | sed -e '/provider_meta/,+2d' \
    | sed -e 's/var/local/g' \
    | sed -e 's/local\.tier/"development"/g' \
    | sed -e 's/local\.hvn_cidr_block/"172.25.32.0\/20"/g'
}

generate_base_existing_vnet_terraform () {
    # first replace the tf resource resource_group with a data source
    # next replace references to the resource.resource_group with data.resource_group
    # next replace the module.network references with users specified locals
  generate_base_terraform $1 \
      | sed -e '/^resource "azurerm_resource_group" "rg"/,+3 { /location.*/d; }' \
      | sed -e '/^resource "azurerm_resource_group" "rg"/,+3 { s/name.*/name = local.vnet_rg_name /g; }' \
      | sed -e 's/resource "azurerm_resource_group" "rg"/data "azurerm_resource_group" "rg"/g' \
      | sed -e 's/azurerm_resource_group.rg/data.azurerm_resource_group.rg/g' \
      | sed -e 's/module\.network.vnet_id/local.vnet_id/g' \
      | sed -e 's/module\.network.vnet_subnets\[0\]/local.subnet1_id/g' \
      | sed -e 's/module\.network.vnet_subnets\[1\]/local.subnet2_id/g' \
      | sed -e 's/module\.network.vnet_subnets/\[local.subnet1_id\]/g'
}

generate_existing_vnet_terraform () {
  case $1 in
    vm)
      generate_base_existing_vnet_terraform $1 \
        | sed -e '/azurerm_route_table" "rt"/,+5d' \
        | sed -e '/module "network"/,+16d' 
         # delete the resource group in favor of replace
      ;;
    aks)
      generate_base_existing_vnet_terraform $1 \
        | sed -e '/Create an Azure vnet and authorize Consul server traffic./,+17d' \
        | sed -e '/module\.network/,+d' \
        | sed -e 's/azurerm_virtual_network\.network\.id/local\.vnet_id/' \
        | sed -e 's/azurerm_virtual_network\.network\.subnet/local\.subnet_id/' \
        | sed -e 's/\[local.subnet1_id\]/\[local.subnet1_id,local.subnet2_id\]/g' # horrible but only aks requires two subnets
      ;;
  esac
}

generate_existing_vnet_locals() {
  echo "locals {"
  cat scripts/snips/locals.snip 
  cat "scripts/snips/$1_locals_existing_vnet.snip"
  echo "}"
  echo ""
}

generate_locals () {
  echo "locals {"
  cat scripts/snips/locals.snip 
  cat "scripts/snips/$1_locals_new_vnet.snip"
  echo "}"
  echo ""
}

generate() {
  file=hcp-ui-templates/$1/main.tf
  mkdir -p $(dirname $file)
  generate_locals $1 > $file
  generate_base_terraform $1 >> $file

  file=hcp-ui-templates/$1-existing-vnet/main.tf
  mkdir -p $(dirname $file)
  generate_existing_vnet_locals $1 > $file
  # for the existing VNET template, we want to be sure to use the correct subscription
  generate_existing_vnet_terraform $1 \
    | sed 's/  features {}/  subscription_id = local.subscription_id\n  features {}/' >> $file

}

for platform in vm aks; do
  generate $platform
done

source ./scripts/terraform_fmt.sh

cd test/hcp
go test -update .
cd -