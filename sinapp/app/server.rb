require 'json'
require 'omniauth-cognito-idp'
require 'sinatra/base'
require 'aws-sdk-cognitoidentityprovider'
require 'aws-record'
require 'aws-sdk-s3'
require 'pp'
require 'date'  

require_relative 'data_manip.rb'

class SinApp < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  set :root, File.dirname(__FILE__)
  set :views, Proc.new { File.join(root, "views") }

  before do
    # Consideration for running via AWS Lambda
    if (! request.body.read.empty? and request.body.size > 0)
      request.body.rewind
      @params = Sinatra::IndifferentHash.new
      # Don't try to JSON parse form data
      #   Means the params will have be be obtained via request.params
      #   Actually, the only time we want to parse the body like this is IF it's JSON.
      if request.form_data?
        @params.merge!(request.params)
      else
        @params.merge!(JSON.parse(request.body.read))
      end
    end
  end

  ##################################
  # Index page
  ##################################
  get '/' do
    erb :index
  end

  ##################################
  # Return a Hello world JSON
  ##################################
  get '/hello-world' do
    content_type :json
    { :Output => 'Hello World!' }.to_json
  end

  post '/hello-world' do
      content_type :json
      { :Output => 'Hello World!' }.to_json
  end

  ##################################
  # Dashboard & Upload
  ##################################
  get '/dashboard' do
    redirect '/' unless session[:auth]
    erb :dashboard
  end

  post '/upload' do
    content_type :json
    file = params[:file][:tempfile]

    if session[:auth]
      # Verify header
      unless DataManip.verify_header(file)
        return [200, {message: "Aggregate file header validation failed."}]
      end

      # Append ascribee

      # Write file to S3
      
      return [200, {message: "Data stored"}]
    else
      return [401, {message: "Unauthorized"}]
    end
  end

  ##################################
  # Login using Cognito
  #   From cognito-omniauth small example
  ##################################

  helpers do
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def cognito_idp_client
      Aws::CognitoIdentityProvider::Client.new(region: ENV['AWS_REGION'])
    end

    def s3_client
      Aws::S3::Client.new(region: ENV['AWS_REGION'])
    end
  end

  get '/userinfo' do
    redirect '/' unless session[:auth]

    userinfo = cognito_idp_client.get_user(access_token: session[:auth][:credentials][:token])

    <<-HTML
    <html>
      <head>
        <title>Cognito IdP Test</title>
      </head>
      <body>
        <h1>User Info From Cognito</h1>
        <pre>#{userinfo.to_h.pretty_inspect}</pre>
        <h2>Links</h2>
        <ul>
          <li><a href="/">Home</a></li>
        </ul>
      </body>
    </html>
    HTML
  end

  post '/userinfo' do
    redirect '/' unless session[:auth]

    attributes = params.map { |k, v| {name: k, value: v} }

    result = cognito_idp_client.update_user_attributes(
      user_attributes: attributes,
      access_token: session[:auth][:credentials][:token]
    )

    <<-HTML
    <html>
      <head>
        <title>Cognito IdP Test</title>
      </head>
      <body>
        <h1>Updated User Attributes at Cognito</h1>
        <pre>#{result.to_h.pretty_inspect}</pre>
        <h2>Links</h2>
        <ul>
          <li><a href="/userinfo">Userinfo</a>
          <li><a href="/">Home</a></li>
        </ul>
      </body>
    </html>
    HTML
  end

  # This is the callback uri that need to be provided to cognito: /auth/cognito-idp/callback
  #   Omniauth provides the /auth/cognito-idp endpoint redirection to identity provider (idp)
  get '/auth/:provider/callback' do
    # Trim auth hash to get under 4k limit for cookie size. 
    #   Drop id token (JWT).  The info is in extra already.
    #   Drop refresh_token.  This limits auth to 1 hour.
    auth = request.env['omniauth.auth'].tap do |i|
      i['credentials'].tap do |j|
        j.delete('id_token')
        j.delete('refresh_token')
      end
    end
    
    # Stuff auth into cookie
    session[:auth] = auth
    redirect '/dashboard'
  end

  get '/auth/failure' do
    <<-HTML
    <html>
      <head>
        <title>Auth Failed</title>
      </head>
      <body>
        <h1>Auth Failed</h1>
        <h2> <a href="/">Home</a> </h2>
        <h2> Session </h2>
        <pre>#{session&.pretty_inspect}</pre>
      </body>
    HTML
  end

end

##################################
# Web App with a DynamodDB table
##################################

# Class for DynamoDB table
# This could also be another file you depend on locally.
class FeedbackServerlessSinatraTable
  include Aws::Record
  string_attr :id, hash_key: true
  string_attr :name
  string_attr :feedback
  epoch_time_attr :ts
end
