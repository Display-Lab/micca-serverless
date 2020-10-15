# Modifications copyright (C) 2020 Regents of the Univeristy of Michigan

require 'json'
require 'omniauth-cognito-idp'
require 'sinatra/base'
require 'aws-sdk-cognitoidentityprovider'
require 'aws-record'
require 'aws-sdk-s3'
require 'pp'
require 'date'  
require 'base64'

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
    set :base_url, ""
  else
    set :js_base_url, "https://assets.micca.report"
    set :base_url, "https://larc.micca.report"
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

    def link_bucket_path(path)
      "#{settings.base_url}/#{path}"
    end

    def is_authed?(session)
      expiry = session.dig "auth", "credentials", "expires_at"

      if expiry.nil?
        return false
      else
        return Time.now.to_i < expiry
      end
    end

    def get_user(session)
      begin
        user = cognito_idp_client.get_user(access_token: session[:auth][:credentials][:token])
      rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException => ex
        session.clear
        halt 403
      end

      return user
    end

    def get_user_email(session)
      session&.dig('auth', 'extra', 'raw_info', 'email')
    end

    def get_ascribee(session)
      user = get_user session
      site_attr = user.user_attributes.select{|attr| attr["name"] == "custom:site"}.first
      # Ascribee is the site name
      site_attr['value']
    end

    def is_display_lab?(session)
      ascribee = get_ascribee(session)
      ascribee_dashed = ascribee.gsub(/ /,'-')
      return(ascribee_dashed == "Display-Lab")
    end

    def verify_ascribee_site(session, site)
      ascribee = get_ascribee(session)
      ascribee_dashed = ascribee.gsub(/ /,'-')

      unless ascribee_dashed == site
        halt 403
      end
    end

    def get_s3_obj(key)
      s3 = Aws::S3::Resource.new
      obj = s3.bucket(ENV['BUCKET']).object(key)

      unless obj.exists?
        halt 404
      end

      return obj
    end

    def parse_s3_path(path)
      parts = path.split('/')
      {type: parts[0], ascribee: parts[1], filename: parts[2], path: path}
    end

  end

  ##################################
  # Retrieve Reports & Data  
  ##################################
  get '/reports/:site/:report_name' do
    redirect '/auth/cognito-idp' unless is_authed?(session)

    site = params["site"]
    report_name = params["report_name"]

    
    # Allow display lab to download any report. Verify all other sites.
    unless(is_display_lab? session ) 
      verify_ascribee_site(session, site) 
    end

    # Retrieve object or throw 404
    src = "reports/#{site}/#{report_name}"
    obj = get_s3_obj src

    content_type :pdf
    attachment File.basename(src)

    # Return StringIO
    obj.get.body
  end

  get '/data/:site/:dataset' do
    redirect '/auth/cognito-idp' unless is_authed?(session)

    site = params["site"]
    dataset = params["dataset"]

    # Allow display lab to download any report. Verify all other sites.
    unless(is_display_lab? session ) 
      verify_ascribee_site(session, site) 
    end

    # Retrieve object or throw 404
    src = "data/#{site}/#{dataset}"
    obj = get_s3_obj src

    content_type :csv
    attachment File.basename(src)

    # Return StringIO
    obj.get.body
  end

  ##################################
  # Error pages
  ##################################

  not_found do
    error = env['sinatra.error']
    status = error&.http_status || response&.status
    message = error&.message || "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']}"
    erb :error, layout: true, locals: {http_status: status, message: message,
                                       big_title: "Not Found"}
  end

  error 403 do
    error = env['sinatra.error']
    status = error&.http_status || response&.status
    message = error&.message || "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']}"
    erb :error, layout: true, locals: {http_status: status, message: message,
                                       big_title: "Forbidden"}
  end

  error do
    error = env['sinatra.error']
    status = error&.http_status || response&.status
    message = error&.message || "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']}"
    erb :error, layout: true, locals: {http_status: status, message: message}
  end

  ##################################
  # Index page
  ##################################
  get '/' do
    erb :index, layout: true
  end

  ##################################
  # Dashboard & Upload
  ##################################

  get '/submit' do
    redirect '/auth/cognito-idp' unless is_authed?(session)
    erb :submit, layout: true
  end

  # Target for XHR request from dashboard JS
  post '/upload' do
    content_type :json
    file = params[:file][:tempfile]

    if is_authed?(session)
      # Verify header
      unless DataManip.verify_header(file)
        return [200, {message: "Aggregate file header validation failed."}.to_json]
      end

      # Append ascribee
      user = get_user(session)
      site_attr = user.user_attributes.select{|attr| attr["name"] == "custom:site"}.first
      ascribee = site_attr['value']
      updated_data = DataManip.append_ascribee(file, ascribee)

      # Write file to S3
      asribee_dashed = ascribee.gsub(/ /,'-')
      obj_key = "data/#{asribee_dashed}/#{Time.now.iso8601}_maptg.csv"

      s3 = Aws::S3::Resource.new
      bucket = s3.bucket(ENV['BUCKET'])
      obj = bucket.object(obj_key)
      obj.put(body: updated_data)

      return [200, {message: "Data stored", location: obj_key}.to_json]
    else
      return [403, {message: "Forbidden"}.to_json]
    end
  end

  get '/dashboard' do
    redirect '/auth/cognito-idp' unless is_authed?(session)

    # Ascribee for report lookup
    ascribee = get_ascribee(session)
    ascribee_dashed = ascribee.gsub(/ /,'-')

    # List of datasets and reports keys
    s3 = Aws::S3::Resource.new
    reports = s3.bucket(ENV['BUCKET'])
      .objects({prefix: "reports/#{ascribee_dashed}/"})
      .sort_by(&:last_modified)
      .last(4)
      .collect(&:key)
      .reverse

    datasets = s3.bucket(ENV['BUCKET'])
      .objects({prefix: "data/#{ascribee_dashed}/"})
      .sort_by(&:last_modified)
      .last(4)
      .collect(&:key)
      .reverse

    erb :dashboard, layout: true, locals: {reports: reports, datasets: datasets}
  end

  get '/monitor' do
    redirect '/auth/cognito-idp' unless is_authed?(session)
    ascribee = get_ascribee(session)
    redirect '/dashboard' unless ascribee == "Display Lab"

    # List of datasets and reports keys
    s3 = Aws::S3::Resource.new
    report_hsh = s3.bucket(ENV['BUCKET'])
      .objects({prefix: "reports/"})
      .sort_by(&:last_modified)
      .last(12)
      .collect(&:key)
      .reverse
      .map{|k| parse_s3_path k}

    dataset_hsh = s3.bucket(ENV['BUCKET'])
      .objects({prefix: "data/"})
      .sort_by(&:last_modified)
      .last(12)
      .collect(&:key)
      .reverse
      .map{|k| parse_s3_path k}

    erb :monitor, layout: true, locals: {reports: report_hsh, datasets: dataset_hsh}
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
