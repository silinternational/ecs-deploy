#!/usr/bin/env bash

apk add bats --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted

bats test.bats
