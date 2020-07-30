#!/usr/bin/env bash

# Quick and dirty script to make updates a bit easier

if [[ -z $USER_POOL_ID ]]; then
  echo "USER_POOL_ID needs to be defined"
  echo "export USER_POOL_ID=whatever"
fi

if [[ $1 == "-h" ]]; then
  echo 'Usage: add-user.sh user@example.com "Site Name"'
  exit 0;
fi

if [[ -z $1 ]]; then
  echo 'Args required.  See -h'
  exit 1;
fi

if [[ -z $2 ]]; then
  echo 'Two args required.  See -h'
  exit 1;
fi

aws cognito-idp admin-create-user \
  --user-pool-id ${USER_POOL_ID} \
  --username ${1} \
  --user-attributes Name=email,Value=${1} Name=custom:site,Value="${2}" \
  --desired-delivery-mediums EMAIL
