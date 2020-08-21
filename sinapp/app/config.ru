require 'rack'
require 'rack/contrib'
require 'rack/utils'
require 'rack/session/cookie'
require 'omniauth-cognito-idp'

# Definition of our app
require_relative 'server'

##########################################
# Dummy data for quick-dirty local test
##########################################

ENV['CLIENT_ID'] ||= 'dummy'
ENV['CLIENT_SECRET'] ||= 'dummy'
ENV['COGNITO_USER_POOL_SITE'] ||= 'example.com'
ENV['COGNITO_USER_POOL_ID'] ||= 'dummy'
ENV['AWS_REGION'] ||= 'dummy'

# Should probably die without a cookie secret
ENV['COOKIE_SECRET'] ||= 'TheWorstKeptDEADBEEF'
ENV['DOMAIN'] ||= 'localhost'

# OmniAuth requires session support
use Rack::Session::Cookie, 
  :secret => ENV['COOKIE_SECRET'],
  :domain => ENV['DOMAIN'],
  :key => 'rack.session',
  :path => '/',
  :expire_after => 3500

use OmniAuth::Strategies::CognitoIdP,
  ENV['CLIENT_ID'],
  ENV['CLIENT_SECRET'],
  client_options: { site: "https://#{ENV['COGNITO_USER_POOL_SITE']}",
                    authorize_url: "https://#{ENV['COGNITO_USER_POOL_SITE']}/login"},
  scope: 'email openid profile aws.cognito.signin.user.admin',
  user_pool_id: ENV['COGNITO_USER_POOL_ID'],
  aws_region: ENV['AWS_REGION']

run SinApp
