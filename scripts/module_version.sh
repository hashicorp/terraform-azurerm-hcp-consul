#!/bin/bash

old="0\.2\.0"
new=0.2.1

for platform in vm aks; do
  file=examples/hcp-$platform-demo/main.tf
  sed -i.bak "s/~> $old/~> $new/" $file
  rm -rf $file.bak
done
