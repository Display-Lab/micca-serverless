#!/usr/bin/env bash

#TODO
# Vendorize gem requirements
# Create layer with gem requirements built in appropriate docker image 


# Package application
SINAPP_BUCKET=${SINAPP_BUCKET:-sinatra-sam-demo}
SINAPP_STACK=${SINAPP_BUCKET:-sinatra-stack}

echo "Packaging"
sam package \
  --template-file template.yaml \
  --output-template-file serverless-output.yaml \
  --s3-bucket $SINAPP_BUCKET 

# Deploy

echo "Deploying"
sam deploy \
  --template-file serverless-output.yaml \
  --stack-name $SINAPP_STACK \
  --capabilities CAPABILITY_IAM
