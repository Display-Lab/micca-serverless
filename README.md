# Serverless Sinatra App

Base project is the AWS serverless infrastructure supporting a Sinatra application in the sinapp/app dir.

Forked from: git@github.com:aws-samples/serverless-sinatra-sample

## My notes

- Stuff template parameters in samconfig.toml
- Requires custom domain to provide callback URIs
- Need to create the Cognito User Pool independently of the application stack
- No way to back up Cognito User Pool
- Need to build and bundle the application locally to handle native compiled gems.
  - `build_dependencies.sh` runs `bundling.sh` in a docker container that approximates AWS lambda container.
  - These dependencies are deployed as an AWS Lambda Layer

## Deployment

### Dependencies External  to Application Stack

- S3 bucket for storing application stack package versions
    ```sh
    aws s3 mb s3://micca-app-pkgs
    ```
- S3 bucket for persisting data
    ```sh
    aws s3 mb s3://micca-reports
    ```
- User Pool for handling user auth
    ```
    aws cloudformation create-stack --stack-name micca-users --template-body file://ext-user-pool.yaml
    ```
- Log in to cognito web UI to create users and specify site
    

### Application Stack Deployment

Wrote a convenience script for setting up and tearing down:
```sh
deploy.sh
dismantle.sh
```


## Testing the sinatra app
From the sinatra app directory, `sinapp`, have a terminal running the following.
```sh
fd . app/ spec/ | entr -c bundle exec rspec
```
Any time there are changes to the application or test files, rspec will be run.

## User Management
Using the aws cli

### Adding Users
```sh
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_eXamPLE \
  --username user@example.com \
  --user-attributes Name=email,Value=user@example.com Name=custom:site,Value="Display Lab" \
  --desired-delivery-mediums EMAIL \
```

### List Users
```sh
aws cognito-idp list-users \
  --user-pool-id us-east-1_eXamPLE 
``` 

### Resend User Invite

#### For admin-created users
Run the create user command again with the RESEND message action.
```sh
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_eXamPLE \
  --username user@example.com \
  --message-action "RESEND"
```

#### For non-admin-created users
A bit of ruby code to calculate the HMAC for the API call.
```ruby
#!/usr/bin/env ruby

require 'openssl'
require 'base64'

client_id = "1234exampleclientid" 
client_secret = "examplecl13nts3cr3tstring" 
username="alice@example.com" 
data = username + client_id
digest = OpenSSL::Digest.new('sha256')

hmac = Base64.strict_encode64(OpenSSL::HMAC.digest(digest, client_secret, data))

puts hmac
```

Run the API command to resend the confirmation

```sh
EMAIL="alice@example.com" \
CLIENT_ID="us-east-1_eXamPLE" \
CLIENT_SECRET="ex4mpleS3CR3T" \
SECRET_HASH="abcdefg1234ABDEFG123345examplehmac12345678=" \
aws cognito-idp resend-confirmation-code --client-id $CLIENT_ID --username $EMAIL --secret-hash "${SECRET_HASH}"
```

## Updating the external users stack
Make edits to the template, the fire up the aws cli

```sh
# Get the arn of the stack
aws cloudformation describe-stacks

# Create change set
CHNG_SET_NAME=MU$(date +%Y%m%dT%H%M)

aws cloudformation create-change-set --stack-name arn:of:the:stack \
  --change-set-name ${CHNG_SET_NAME} --template-body file://ext-user-pool.yaml

# Excecute the change set (note the changeset arn from above step)
aws cloudformation execute-change-set --change-set-name arn:of:changeset
```
## Other resources:

Ruby Sinatra on AWS Lambda: https://blog.eq8.eu/article/sinatra-on-aws-lambda.html

We want FaaS for Ruby: https://www.serverless-ruby.org/

## License

Licensed under the Apache 2.0 License.
