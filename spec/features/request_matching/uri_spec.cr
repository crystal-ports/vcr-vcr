require "../../spec_helper"

Spectator.describe "Request Matching: URI" do
  # Use the :uri request matcher to match requests on the request URI.
  #
  # The :uri matcher is used (along with the :method matcher) by default
  # if you do not specify how requests should match.

  # Given a previously recorded cassette file "cassettes/example.yml" with:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: post
      uri: http://example.com/foo
      body:
        encoding: UTF-8
        string: ""
      headers: {}
    response:
      status:
        code: 200
        message: OK
      headers:
        Content-Length:
        - "12"
      body:
        encoding: UTF-8
        string: foo response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  - request:
      method: post
      uri: http://example.com/bar
      body:
        encoding: UTF-8
        string: ""
      headers: {}
    response:
      status:
        code: 200
        message: OK
      headers:
        Content-Length:
        - "12"
      body:
        encoding: UTF-8
        string: bar response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe ":uri matcher" do
    it "is a registered matcher" do
      expect(VCR.request_matchers[:uri]).not_to be_nil
    end

    it "is used by default with :method" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette.match_requests_on).to eq([:method, :uri])
    end

    it "can be used alone" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:uri]
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.match_requests_on).to eq([:uri])
    end

    describe "replay interaction that matches the request URI" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "returns the response for /bar when requesting /bar URI" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:uri]

        VCR.use_cassette("example", options) do
          # Create a request for /bar
          request = VCR::Request.new("get", "http://example.com/bar", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("bar response")
          end
        end
      end

      it "returns the response for /foo when requesting /foo URI" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:uri]

        VCR.use_cassette("example", options) do
          # Create a request for /foo
          request = VCR::Request.new("get", "http://example.com/foo", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("foo response")
          end
        end
      end

      it "matches regardless of HTTP method when only :uri is specified" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:uri]

        VCR.use_cassette("example", options) do
          # The cassette has POST requests, but we're using GET
          # Since we only match on :uri, it should still match
          request = VCR::Request.new("get", "http://example.com/foo", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("foo response")
          end
        end
      end
    end

    describe "with :method and :uri (default)" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "does not match when method differs" do
        # Default options use [:method, :uri]
        VCR.use_cassette("example") do
          # The cassette has POST requests, we're using GET
          request = VCR::Request.new("get", "http://example.com/foo", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # Should not match because method differs
          expect(response).to be_nil
        end
      end

      it "matches when both method and URI match" do
        VCR.use_cassette("example") do
          # Use POST to match the cassette
          request = VCR::Request.new("post", "http://example.com/foo", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("foo response")
          end
        end
      end
    end
  end
end
