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

  # Use local js files when not in production
  if( ENV['RACK_ENV'] == 'local')
    set :js_base_url, ""
  else
    set :js_base_url, "https://assets.micca.report"
  end

  # Consideration for running via AWS Lambda
  before do
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

  ####################
  # Helper Functions #
  ####################

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

  #####################
  # Utility Functions #
  #####################

  def get_user(session)
    session&.dig('auth', 'extra', 'raw_info', 'email')
  end

  ##################################
  # Index page
  ##################################
  get '/' do
    user = get_user(session)
    erb :index, layout: true, locals: {user: user}
  end

  ##################################
  # Dashboard & Upload
  ##################################

  # Provide valid endpoint for submitting data.
  #   Redirect to dashboard in the meantime.
  get '/submit' do
    if session[:auth]
      redirect '/dashboard'
    else
      redirect '/auth/cognito-idp'
    end
  end

  get '/dashboard' do
    redirect '/auth/cognito-idp' unless session[:auth]
    user = get_user(session)
    erb :dashboard, layout: true, locals: {user: user}
  end

  # Target for XHR request from dashboard JS
  post '/upload' do
    content_type :json
    file = params[:file][:tempfile]

    if session[:auth]
      # Verify header
      unless DataManip.verify_header(file)
        return [200, {message: "Aggregate file header validation failed."}.to_json]
      end

      # Append ascribee
      user = cognito_idp_client.get_user(access_token: session[:auth][:credentials][:token])
      site_attr = user.user_attributes.select{|attr| attr["name"] == "custom:site"}.first
      ascribee = site_attr['value']
      updated_data = DataManip.append_ascribee(file, ascribee)

      # Write file to S3
      asribee_dashed = ascribee.sub(/ /,'-')
      obj_key = "data/#{asribee_dashed}/#{Time.now.iso8601}_maptg.csv"

      s3 = Aws::S3::Resource.new
      bucket = s3.bucket(ENV['BUCKET'])
      obj = bucket.object(obj_key)
      obj.put(body: updated_data)

      return [200, {message: "Data stored", location: obj_key}.to_json]
    else
      return [401, {message: "Unauthorized"}.to_json]
    end
  end



  #######################
  # Login using Cognito #
  #######################
  
  # This is the callback uri that needs to be provided to cognito: /auth/cognito-idp/callback
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

  get '/logout' do
    logout_url = "https://#{ENV['COGNITO_USER_POOL_SITE']}/logout"

    if( ENV['RACK_ENV'] == 'production')
      query = "client_id=#{ENV['CLIENT_ID']}&logout_uri=https://#{ENV['DOMAIN']}"
    else
      query = "client_id=#{ENV['CLIENT_ID']}&logout_uri=http://#{ENV['DOMAIN']}:40123"
    end

    session[:auth] = nil
    session.clear
    redirect "#{logout_url}?#{query}"
  end
end
