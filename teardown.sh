#!/usr/bin/env bash

SINAPP_BUCKET=${SINAPP_BUCKET:-sinatra-sam-demo}
SINAPP_STACK=${SINAPP_BUCKET:-sinatra-stack}


echo "Teardown"

# Delete the layer and the app zips
aws s3 rm --recursive s3://${SINAPP_BUCKET}

# Back up any data that needs backing.

echo "Delete Stack"
aws cloudformation delete-stack --stack-name $SINAPP_STACK

echo "Waiting for stack deletion"
aws cloudformation wait stack-delete-complete --stack-name $SINAPP_STACK

