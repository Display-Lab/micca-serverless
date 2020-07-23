require 'spec_helper'

# Tests for server.rb
describe SinApp do
  include Rack::Test::Methods

  context "GET index page" do
    let(:resp){ get '/' }

    it "have an index page" do
      get '/'
      expect(resp).to be_ok
    end

    it "have a link to sign in on index page" do
      get '/'
      expect(resp.body).to include('<a href="/auth/cognito-idp">')
    end
  end

  
  context "Authenticating" do
    it "callback after succesful login goes to dashboard" do
      get '/auth/:provider/callback', {provider: 'cognito-idp'}, {'omniauth.auth' => make_full_authed_hash} 
      expect(last_response.redirect?).to be true
      expect(last_response.location).to end_with "/dashboard"
      follow_redirect!
      expect(last_response).to be_ok
    end

    it "put auth information in session" do
      skip("test cookie based session")
    end
  end

  context "Go to upload page" do
    it "redirects to login when unathenticated" do
      skip "test unauthed session"

    end

    it "renders just find when authenticated" do
      skip "test authed"

    end
  end
end
