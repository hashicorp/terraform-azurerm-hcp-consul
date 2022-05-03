#!/bin/bash

old="0\.1\.0"
new=0.1.0

for platform in vm; do
  file=examples/hcp-$platform-demo/main.tf
  sed -i.bak "s/~> $old/~> $new/" $file
  rm -rf $file.bak
done
