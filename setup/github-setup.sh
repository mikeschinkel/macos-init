#!/usr/bin/env zsh

mkdir -p ~/.ssh
chmod 700 ~/.ssh
cp /Volumes/mikeschinkel/.ssh/config .
cp /Volumes/mikeschinkel/.ssh/mike@newclarity.net-github.com .
cp /Volumes/mikeschinkel/.ssh/mike@newclarity.net-github.com.pub .
chmod 600 mike@newclarity.net-github.com
chmod 600 config
chmod 644 mike@newclarity.net-github.com.pub
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/mike@newclarity.net-github.com
ssh -T git@github.com
git config --global user.name "Mike Schinkel"
git config --global user.email "mike@newclarity.net"
