#!/usr/bin/env zsh

brew install podmain
brew install podman-desktop
sudo /usr/local/Cellar/podman/5.4.2/bin/podman-mac-helper install
podman machine stop
podman machine start

