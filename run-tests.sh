#!/usr/bin/env bash

apk add bats --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community/ --allow-untrusted

bats test.bats
