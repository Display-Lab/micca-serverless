require "rubygems"
require "json"
require "pathname"

def smoke_test_handler(event:, context:)
  # Check the gems available on each gem path
  result = Gem.path.collect do |p|
    path = Pathname.new(p).join('gems')
    if path.exist?
      path.children 
    else
      p
    end
  end

  { statusCode: 200, body: JSON.generate(result) }
end
