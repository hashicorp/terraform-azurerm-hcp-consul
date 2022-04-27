#!/bin/bash

generate_base_terraform () {
  cat examples/hcp-$1-demo/{providers,main,intentions,output}.tf \
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
      | sed -e 's/module\.network.vnet_subnets\[0\]/local.subnet_id/g' \
      | sed -e 's/module\.network.vnet_subnets/[local.subnet_id]/g' 
}

generate_existing_vnet_terraform () {
  case $1 in
    vm)
      generate_base_existing_vnet_terraform $1 \
        | sed -e '/azurerm_route_table" "rt"/,+5d' \
        | sed -e '/module "network"/,+16d' 
         # delete the resource group in favor of replace
      ;;
  esac
}

generate_existing_vnet_locals() {
  echo "locals {"
  cat scripts/snips/locals.snip 
  cat scripts/snips/locals_existing_vnet.snip
  echo "}"
  echo ""
}

generate_locals () {
  echo "locals {"
  cat scripts/snips/locals.snip 
  cat scripts/snips/locals_new_vnet.snip
  echo "}"
  echo ""
}

generate() {
  file=hcp-ui-templates/$1/main.tf
  mkdir -p $(dirname $file)
  generate_locals > $file
  generate_base_terraform $1 >> $file

  file=hcp-ui-templates/$1-existing-vnet/main.tf
  mkdir -p $(dirname $file)
  generate_existing_vnet_locals $1 > $file
  generate_existing_vnet_terraform $1 >> $file

}

for platform in vm; do
  generate $platform
done

source ./scripts/terraform_fmt.sh

cd test/hcp
go test -update .
cd -