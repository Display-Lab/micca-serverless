#!/usr/bin/env bash

# Vendorize gem requirements
# Create layer with gem requirements built in appropriate docker image 
# See build_dependencies.sh

SINAPP_BUCKET=${SINAPP_BUCKET:-micca-app-pkgs}
SINAPP_STACK=${SINAPP_STACK:-micca-application-stack}
ASSETS_BUCKET=${ASSETS_BUCKET:-assets.micca.report}

echo "Packaging"
sam package \
  --template-file template.yaml \
  --output-template-file serverless-output.yaml \
  --s3-bucket $SINAPP_BUCKET 

echo "Deploying"
sam deploy \
  --template-file serverless-output.yaml \
  --stack-name $SINAPP_STACK \
  --capabilities CAPABILITY_IAM

echo "Sync S3 Assets"
aws s3 sync sinapp/app/public/ s3://${ASSETS_BUCKET}
