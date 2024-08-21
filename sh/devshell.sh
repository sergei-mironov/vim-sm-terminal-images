#!/bin/sh

. ./env.sh
nix-shell -p pkgs.python3Packages.ipython
