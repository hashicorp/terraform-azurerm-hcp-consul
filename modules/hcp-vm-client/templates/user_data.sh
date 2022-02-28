#!/usr/bin/env bash

cd /home/adminuser
echo "${setup}" | base64 -d | zcat > setup.sh
chown adminuser:adminuser setup.sh
chmod +x setup.sh
./setup.sh
