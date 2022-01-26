#!/bin/bash

cd aws/$1
tar cvzf ../../$1-aws.box metadata.json Vagrantfile
