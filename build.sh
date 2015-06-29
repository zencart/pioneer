#!/usr/bin/env bash

# install required vagrant plugin to handle reloads during provisioning
vagrant plugin install vagrant-reload

# start with no machines
vagrant destroy -f
rm -rf .vagrant

time vagrant up --provider virtualbox 2>&1 | tee virtualbox-build-output.log
vagrant halt
vagrant package --base `ls ~/VirtualBox\ VMs | grep HabitatBase` --output habitat.box

ls -lh habitat.box
vagrant destroy -f
rm -rf .vagrant

