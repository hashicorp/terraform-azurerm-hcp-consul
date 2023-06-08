#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


old="0\.3\.2"
new=0.4.0

for platform in vm aks; do
  file=examples/hcp-$platform-demo/main.tf
  sed -i.bak "s/~> $old/~> $new/" $file
  rm -rf $file.bak
done
