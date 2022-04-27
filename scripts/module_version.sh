#!/bin/bash

# NOTE: This does nothing until we release the modules.
# don't commit this until we do. 

old="0\.6\.1"
new=0.7.0

for platform in vm; do
  file=examples/hcp-$platform-demo/main.tf
  sed -i.bak "s/~> $old/~> $new/" $file
  rm -rf $file.bak
done
