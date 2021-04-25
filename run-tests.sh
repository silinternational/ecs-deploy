#!/usr/bin/env bash

function install_bats() {
    local os=$( uname -s | tr '[:upper:]' '[:lower:]' )
    [[ "$os" == "darwin" ]] && brew install bats
    [[ "$os" == "linux" ]] && apk add bats --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community/ --allow-untrusted
}

command -v "bats" || install_bats
bats test