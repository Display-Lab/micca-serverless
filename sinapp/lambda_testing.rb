require 'json'
require 'rack'
require 'base64'
require 'pry'

# Injected ENV vars 
ENV['AWS_REGION']="us-east-1"
ENV['BUCKET']='display-lab'

# Global object that responds to the call method. Stay outside of the handler
# to take advantage of container reuse
$app ||= Rack::Builder.parse_file("#{__dir__}/app/config.ru").first
ENV['RACK_ENV'] ||= 'production'


# def handler(event:, context:)
  # Check if the body is base64 encoded. If it is, try to decode it
  body = ''
  #body = if event['isBase64Encoded']
  #  Base64.decode64 event['body']
  #else
  #  event['body']
  #end || ''

  # Rack expects the querystring in plain text, not a hash
  headers = {}

  # Environment required by Rack (http://www.rubydoc.info/github/rack/rack/file/SPEC)
  env = {
    'REQUEST_METHOD' => "GET",
    'SCRIPT_NAME' => '',
    'PATH_INFO' => "/demo/demo.pdf",
    'QUERY_STRING' => {},
    'SERVER_NAME' => headers.fetch('Host', 'localhost'),
    'SERVER_PORT' => headers.fetch('X-Forwarded-Port', 443).to_s,

    'rack.version' => Rack::VERSION,
    'rack.url_scheme' => headers.fetch('CloudFront-Forwarded-Proto') { headers.fetch('X-Forwarded-Proto', 'https') },
    'rack.input' => StringIO.new(body),
    'rack.errors' => $stderr,
  }

  # Pass request headers to Rack if they are available
  headers.each_pair do |key, value|
    # 'CloudFront-Forwarded-Proto' => 'CLOUDFRONT_FORWARDED_PROTO'
    # Content-Type and Content-Length are handled specially per the Rack SPEC linked above.
    name = key.upcase.gsub '-', '_'
    header = case name
      when 'CONTENT_TYPE', 'CONTENT_LENGTH'
        name
      else
        "HTTP_#{name}"
    end
    env[header] = value.to_s
  end

  begin
    # Response from Rack must have status, headers and body
    status, headers, body = $app.call env

    # switch on the header mime-type (API Gateway only)
    if headers["Content-Type"] == Rack::Mime.mime_type(".pdf")
      # Assume body is IO of some sort. Read & base64 encode
      body_content = Base64.encode64(body.read)
      is_base64_encoded = true
    else
      # Assume body is an array. We combine all the items to a single string
      body_content = ""

      body.each do |item|
        body_content += item.to_s
      end
      is_base64_encoded = false
    end

    # We return the structure required by AWS API Gateway since we integrate with it
    # https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html
    response = {
      'statusCode' => status,
      'headers' => headers,
      'body' => body_content,
      'isBase64Encoded' => is_base64_encoded
    }
  rescue Exception => exception
    # If there is _any_ exception, we return a 500 error with an error message
    response = {
      'statusCode' => 500,
      'body' => exception.message
    }
  end

  binding.pry

  # By default, the response serializer will call #to_json for us
  response
#end
