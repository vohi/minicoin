#!/bin/bash
set -euo pipefail

[[ -d ~/.ssh ]] && rm -rf ~/.ssh

mkdir ~/.ssh
curl -o ~/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub
chmod 0700 ~/.ssh
chmod 0644 ~/.ssh/authorized_keys
