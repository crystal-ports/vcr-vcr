require "../../spec_helper"

Spectator.describe "Request Matching: Method" do
  # Use the :method request matcher to match requests on the HTTP method
  # (i.e. GET, POST, PUT, DELETE, etc). You will generally want to use
  # this matcher.
  #
  # The :method matcher is used (along with the :uri matcher) by default
  # if you do not specify how requests should match.

  describe ":method matcher" do
    it "is a registered matcher" do
      expect(VCR.request_matchers[:method]).not_to be_nil
    end

    it "is used by default with :uri" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette.match_requests_on).to contain(:method)
    end

    describe "replay interaction that matches the HTTP method" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", METHOD_MATCHING_CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "returns the POST response when making a POST request" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:method]

        VCR.use_cassette("example", options) do
          # Create a POST request - should match the POST interaction
          request = VCR::Request.new("post", "http://any-host.com/", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("post response")
          end
        end
      end

      it "returns the GET response when making a GET request" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:method]

        VCR.use_cassette("example", options) do
          # Create a GET request - should match the GET interaction
          request = VCR::Request.new("get", "http://any-host.com/", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("get response")
          end
        end
      end

      it "does not match when method differs" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:method]

        VCR.use_cassette("example", options) do
          # Use GET first to consume it
          request1 = VCR::Request.new("get", "http://any-host.com/", nil, {} of String => Array(String))
          VCR.http_interactions.response_for(request1)

          # Use POST to consume it
          request2 = VCR::Request.new("post", "http://any-host.com/", nil, {} of String => Array(String))
          VCR.http_interactions.response_for(request2)

          # Now PUT should not match (no PUT in cassette)
          request3 = VCR::Request.new("put", "http://any-host.com/", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request3)

          expect(response).to be_nil
        end
      end
    end
  end
end
