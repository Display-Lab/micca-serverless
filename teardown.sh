#!/usr/bin/env bash

SINAPP_BUCKET=${SINAPP_BUCKET:-sinatra-sam-demo}
SINAPP_STACK=${SINAPP_BUCKET:-sinatra-stack}


echo "Teardown"
# TODO: Clean out and buckets that need cleaning.
# Back up any data that needs backing.


echo "Delete Stack"
aws cloudformation delete-stack --stack-name $SINAPP_STACK

