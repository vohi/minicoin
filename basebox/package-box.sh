#!/usr/bin/env bash
vagrant package --base $1-base --output $1-base.box $1-base
vagrant box add --name tqtc/$1 $1-base.box

