require 'rack/test'
require 'rspec'
require 'omniauth-cognito-idp'
require 'pry'

ENV['APP_ENV'] = 'test'
require_relative '../app/server.rb'

def app 
  described_class 
end

def stub_client
  @stub_client ||= begin
    Aws::DynamoDB::Client.new(stub_responses: true) # don't send real calls to DynamoDB in test env
  end
end

RSpec.configure do |config|
  config.before(:each) do
    FeedbackServerlessSinatraTable.configure_client(client: stub_client)
  end
end

def make_full_authed_hash
  {"provider"=>"cognito-idp",
   "uid"=>"deadbeef-2bad-b000-f33d-feed4facef00",
   "info"=>{"name"=>nil, "email"=>"grosscol@gmail.com", "phone"=>nil},
   "credentials"=>
    {"token"=>
      "DEADBEEF123456789DEADBEEF123456789DEADBEEF123456789DEADBEEF123456789",
     "id_token"=>
      "DEADBEEF123456789DEADBEEF123456789DEADBEEF123456789DEADBEEF123456789",
     "refresh_token"=>
      "DEADBEEF123456789DEADBEEF123456789DEADBEEF123456789DEADBEEF123456789",
     "expires_at"=>1595521253,
     "expires"=>true},
   "extra"=>
    {"raw_info"=>
      {"at_hash"=>"BASE64endocingleft128b",
       "sub"=>"deadbeef-2bad-b000-f33d-feed4facef00",
       "event_id"=>"deadbeef-1234-5678-9100-deadbeef1234",
       "auth_time"=>1595517653,
       "cognito:username"=>"deadbeef-2bad-b000-f33d-feed4facef00",
       "email"=>"usernaem@example.com"}}
  }
end


# We could use native RSpec `post '/endpoint', param1: 'foo', param2: 'bar'
# But this method better replicates how AWS API Gateway forwards the request
# to our AWS Lamda function: In './lambda.rb' needs to reset `rack.input` with
# JSON string Lambda event body.
def api_gateway_post(path, params)
  api_gateway_body_fwd = params.to_json
  rack_input = StringIO.new(api_gateway_body_fwd)

  post path, real_params = {}, {"rack.input" => rack_input}
end

def json_result
  JSON.parse(last_response.body)
end
