require "../../spec_helper"

Spectator.describe "Request Matching: Body" do
  # Use the :body request matcher to match requests on the request body.

  # Given a previously recorded cassette file "cassettes/example.yml" with:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: post
      uri: http://example.net/some/long/path
      body:
        encoding: UTF-8
        string: body1
      headers: {}
    response:
      status:
        code: 200
        message: OK
      headers:
        Content-Length:
        - "14"
      body:
        encoding: UTF-8
        string: body1 response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  - request:
      method: post
      uri: http://example.net/some/long/path
      body:
        encoding: UTF-8
        string: body2
      headers: {}
    response:
      status:
        code: 200
        message: OK
      headers:
        Content-Length:
        - "14"
      body:
        encoding: UTF-8
        string: body2 response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe ":body matcher" do
    it "is a registered matcher" do
      expect(VCR.request_matchers[:body]).not_to be_nil
    end

    it "can be used in match_requests_on" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:body]
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.match_requests_on).to contain(:body)
    end

    describe "replay interaction that matches the body" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "returns the response for body2 when requesting with body2" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:body]

        VCR.use_cassette("example", options) do
          # Create a request with body2
          request = VCR::Request.new("put", "http://example.com/", "body2", {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("body2 response")
          end
        end
      end

      it "returns the response for body1 when requesting with body1" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:body]

        VCR.use_cassette("example", options) do
          # Create a request with body1
          request = VCR::Request.new("put", "http://example.com/", "body1", {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("body1 response")
          end
        end
      end

      it "matches regardless of HTTP method or URI when only :body is specified" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:body]

        VCR.use_cassette("example", options) do
          # The cassette has POST requests to example.net, but we're using PUT to example.com
          # Since we only match on :body, it should still match
          request = VCR::Request.new("put", "http://example.com/different/path", "body1", {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("body1 response")
          end
        end
      end

      it "does not match when body differs" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:body]

        VCR.use_cassette("example", options) do
          # Request with a body that doesn't match any in the cassette
          request = VCR::Request.new("post", "http://example.net/some/long/path", "different_body", {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # Should not match because body differs
          expect(response).to be_nil
        end
      end
    end

    describe "with :method, :uri and :body" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "matches when method, URI and body all match" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:method, :uri, :body]

        VCR.use_cassette("example", options) do
          # Use exact same method, URI and body from cassette
          request = VCR::Request.new("post", "http://example.net/some/long/path", "body1", {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("body1 response")
          end
        end
      end

      it "does not match when URI differs" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:method, :uri, :body]

        VCR.use_cassette("example", options) do
          # Different URI but same method and body
          request = VCR::Request.new("post", "http://different.com/path", "body1", {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # Should not match because URI differs
          expect(response).to be_nil
        end
      end
    end
  end
end
