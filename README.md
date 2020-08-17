# Serverless Sinatra App

Base project is the deployment wrapper around a sinatra application in the sinapp dir

Plan is to:
1. Develop the deployment and wiring strategy in this project.
2. Develop the application under the sinapp directory.

## My notes

- Using bucket sinatra-sam-demo
- Stuff template parameters in samconfig.toml
- Requires custom domain to provide callback URIs
- Need to create the Cognito User Pool independently of the application stack
- No way to back up Cognito User Pool
- Need to build and bundle the application locally to handle native compiled gems.
    `build_dependencies.sh` runs `bundling.sh` in a docker container that approximates AWS lambda container.

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
## Running Ruby Sinatra on AWS Lambda
Originally from: git@github.com:aws-samples/serverless-sinatra-sample

This sample code helps get you started with a simple Sinatra web app deployed on AWS Lambda. It is tested with Ruby 2.5.x and bundler-1.17.x. 

Additional details can be found at: https://aws.amazon.com/blogs/compute/announcing-ruby-support-for-aws-lambda/

__Other resources:__

Ruby Sinatra on AWS Lambda: https://blog.eq8.eu/article/sinatra-on-aws-lambda.html

We want FaaS for Ruby: https://www.serverless-ruby.org/

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


What's Here
-----------

This sample includes:

* README.md - this file
* Gemfile - Gem requirements for the sample application
* app/config.ru - this file contains configuration for Rack middleware
* app/server.rb - this file contains the code for the sample service
* app/views - this directory has the template files
* spec/ - this directory contains the RSpec unit tests for the sample application
* template.yaml - this file contains the description of AWS resources used by AWS
  CloudFormation to deploy your serverless application
* pipeline-cfn.yaml - this is the CloudFormation template to create the CodePipeline and the other needed resources. You need to fork the repo if you use a personal GitHub token
* buildspec.yml - this file contains build commands used by AWS CodeBuild

Getting Started
---------------

These directions assume you already have Ruby 2.5.x and [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/installing.html) installed and configured. Please fork the repo and create an [access token](https://github.com/settings/tokens/new) if you want to create a [CodePipeline](https://aws.amazon.com/codepipeline/) to deploy the app. The pipeline-cfn.yaml template can be used to automate the process.

To work on the sample code, you'll need to clone your project's repository to your local computer. If you haven't, do that first. You can find a guide [here](https://help.github.com/articles/cloning-a-repository/).

1. Ensure you are using ruby version 2.5.x

2. Install bundle

        $ gem install bundler -v "~> 1.17"

3. Install Ruby dependencies for this service

        $ bundle install

4. Download the Gems to the local vendor directory

        $ bundle install --deployment

5. Create the deployment package (note: if you don't have a S3 bucket, you need to create one):

        $ aws cloudformation package \
            --template-file template.yaml \
            --output-template-file serverless-output.yaml \
            --s3-bucket { your-bucket-name }
            
    Alternatively, if you have [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html) installed, you can run the following command 
    which will do the same

        $ sam package \
            --template-file template.yaml \
            --output-template-file serverless-output.yaml \
            --s3-bucket { your-bucket-name }
            
6. Deploying your application

        $ aws cloudformation deploy --template-file serverless-output.yaml \
            --stack-name { your-stack-name } \
            --capabilities CAPABILITY_IAM
    
    Or use SAM CLI

        $ sam deploy \
            --template-file serverless-output.yaml \
            --stack-name { your-stack-name } \
            --capabilities CAPABILITY_IAM

7. Once the deployment is complete, you can find the application endpoint from the CloudFormation outputs tab. Alternatively, you can find it under the Stages link from the API gateway console.

__Note__:
You can also use an [Application Load Balancer](https://aws.amazon.com/elasticloadbalancing/features/#Details_for_Elastic_Load_Balancing_Products) instead of API gateway. 
For details, please visit https://docs.aws.amazon.com/elasticloadbalancing/latest/application/lambda-functions.html

What Do I Do Next?
------------------

If you have checked out a local copy of your repository you can start making changes to the sample code. 

Learn more about Serverless Application Model (SAM) and how it works here: https://github.com/awslabs/serverless-application-model/blob/master/HOWTO.md

AWS Lambda Developer Guide: http://docs.aws.amazon.com/lambda/latest/dg/deploying-lambda-apps.html

How Do I Add Template Resources to My Project?
------------------

To add AWS resources to your project, you'll need to edit the `template.yaml`
file in your project's repository. You may also need to modify permissions for
your project's IAM roles. After you push the template change, AWS CloudFormation provisions the resources for you.

## License

This library is licensed under the Apache 2.0 License.
