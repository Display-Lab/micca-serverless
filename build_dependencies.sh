#!/usr/bin/env bash

docker run -it --rm --user $(id -u):$(id -g) -v \
  "$PWD":/var/task lambci/lambda:build-ruby2.5 \
  ./bundling.sh
