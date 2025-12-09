#!/usr/bin/env bash
# Copyright IBM Corp. 2022, 2023
# SPDX-License-Identifier: MPL-2.0


cd /home/adminuser
echo "${setup}" | base64 -d | zcat > setup.sh
chown adminuser:adminuser setup.sh
chmod +x setup.sh
./setup.sh
