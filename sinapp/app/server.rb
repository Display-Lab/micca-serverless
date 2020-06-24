require 'omniauth-cognito-idp'
require 'sinatra/base'
require 'aws-sdk-cognitoidentityprovider'
require 'aws-record'
require 'pp'

class SinApp < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  set :root, File.dirname(__FILE__)
  set :views, Proc.new { File.join(root, "views") }

  before do
    if (! request.body.read.empty? and request.body.size > 0)
      request.body.rewind
      @params = Sinatra::IndifferentHash.new
      @params.merge!(JSON.parse(request.body.read))
    end
  end

  ##################################
  # For the index page
  ##################################
  get '/' do
    erb :index
  end

  ##################################
  # Debug
  ##################################
  get '/env' do
    content_type :json
    ENV.to_hash.to_json
  end

  get '/sess' do
    content_type :json
    session.to_hash.to_json
  end

  get '/dbg' do
    content_type :json
    cognito_idp_client.to_json
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
  # Stub dashboard
  ##################################
  get '/dashboard' do
    erb :dashboard
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

  get '/feedback' do
    erb :feedback
  end

  get '/api/feedback' do
    content_type :json
    items = FeedbackServerlessSinatraTable.scan()
    items
      .map { |r| { :ts => r.ts, :name => r.name, :feedback => r.feedback } }
      .sort { |a, b| a[:ts] <=> b[:ts] }
      .to_json
  end

  post '/api/feedback' do
    content_type :json
    item = FeedbackServerlessSinatraTable.new(id: SecureRandom.uuid, ts: Time.now)
    item.name = params[:name]
    item.feedback = params[:feedback]
    item.save! # raise an exception if save fails

    item.to_h.to_json
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
  end

  get '/login' do
    #   <pre>#{session[:auth].pretty_inspect}</pre>
    <<-HTML
    <html>
      <head>
        <title>Cognito IdP Test</title>
      </head>
      <body>
        <h1>Welcome</h1>
        <h2>Session Auth</h2>
        <h2>Links</h2>
        <ul>
          <li><a href="/auth/cognito-idp">Sign In</a></li>
          <li><a href="/userinfo">Userinfo</a></li>
        </ul>
      </body>
    </html>
    HTML
  end

  get '/userinfo' do
    redirect '/' unless session[:auth]

    userinfo = cognito_idp_client.get_user(access_token: session[:auth][:credentials][:token])

    form_fields = userinfo.user_attributes.reject do |attr|
      %w[sub].include?(attr.name) || attr.name.end_with?('_verified')
    end

    form_inputs = form_fields.map { |attr| <<-HTML }.join("\n")
      <dt><label for="#{attr.name}">#{attr.name}</label></dt>
      <dd><input type="text" name="#{attr.name}" value="#{h(attr.value)}" /></dd>
    HTML

    <<-HTML
    <html>
      <head>
        <title>Cognito IdP Test</title>
      </head>
      <body>
        <h1>User Info From Cognito</h1>
        <pre>#{userinfo.to_h.pretty_inspect}</pre>
        <form action="/userinfo" method="POST">
          #{form_inputs}
          <input type="submit" value="Update" />
        </form>
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

  # This does the login? or after the call to the idp login?
  # This is the callback uri that need to be provided to cognito ?
  #   /auth/cognito-idp/callback ?
  #   Omniauth provides the /auth/cognito-idp endpoint? yes.
  #     What to pass to it? email and password?
  #get '/auth/:provider/callback' do
  get '/auth/old/callback' do
    auth = request.env['omniauth.auth']

    session[:auth] = auth

    <<-HTML
    <html>
      <head>
        <title>Cognito IdP Test</title>
      </head>
      <body>
        <h1>Authenticated with #{params[:name]}</h1>
        <h2>Authentication Object</h2>
        <pre>#{auth&.pretty_inspect}</pre>

        <h2> DEBUG: request env </h2>
        <pre>#{request.env&.pretty_inspect}</pre>

        <h2>Links</h2>
        <ul>
          <li><a href="/">Home</a></li>
          <li><a href="/userinfo">Userinfo</a></li>
        </ul>
      </body>
    </html>
    HTML
  end

  get '/auth/:provider/callback' do
    "called us back"
  end

  get '/auth/failure' do

    <<-HTML
    <html>
      <head>
        <title>Auth Failed</title>
      </head>
      <body>
        <h2> DEBUG: request env </h2>
        <pre>#{request.env&.pretty_inspect}</pre>
      </body>
    HTML
  end

end
