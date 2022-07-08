#!/bin/bash

file () {
  echo "examples/hcp-$1-demo/main.tf"
}

dev () {
  platform=$1
  perl -i -pe "BEGIN{undef \$/;} s/hashicorp\/hcp-consul\/azurerm\/\/modules\/hcp-$platform-client\"\r?\n  /..\/..\/modules\/hcp-$platform-client\"\n  # /smg" $(file $1)
}

prod () {
  platform=$1
  perl -i -pe "s/# version/version/smg" $(file $1)
  perl -i -pe "s/\.\.\/\.\.\/modules\/hcp-$platform-client/hashicorp\/hcp-consul\/azurerm\/\/modules\/hcp-$platform-client/smg" $(file $1)
}

isDev () {
  grep -q "# version" $(file $1)
  echo $?
}

for platform in vm aks; do
  dev=$(isDev $platform)
  if [ $dev -eq 0 ]; then
    prod $platform
  else
    dev $platform
  fi
done