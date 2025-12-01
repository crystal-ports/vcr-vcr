require "../../spec_helper"

Spectator.describe "Request Matching: Headers" do
  # Use :headers to match requests on the request headers.
  #
  # Note that headers are generally less deterministic than other
  # request attributes, so you should consider carefully before using
  # this matcher.

  # Given a previously recorded cassette file "cassettes/example.yml" with:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: post
      uri: http://example.com/api
      body:
        encoding: UTF-8
        string: ""
      headers:
        X-Custom-Header:
        - custom_value_1
    response:
      status:
        code: 200
        message: OK
      headers:
        Content-Length:
        - "17"
      body:
        encoding: UTF-8
        string: header1 response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  - request:
      method: post
      uri: http://example.com/api
      body:
        encoding: UTF-8
        string: ""
      headers:
        X-Custom-Header:
        - custom_value_2
    response:
      status:
        code: 200
        message: OK
      headers:
        Content-Length:
        - "17"
      body:
        encoding: UTF-8
        string: header2 response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe ":headers matcher" do
    it "is a registered matcher" do
      expect(VCR.request_matchers[:headers]).not_to be_nil
    end

    it "can be used in match_requests_on" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:headers]
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.match_requests_on).to contain(:headers)
    end

    describe "replay interaction that matches the headers" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "returns the response for header value 1 when requesting with that header" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:headers]

        VCR.use_cassette("example", options) do
          # Create a request with custom_value_1 header
          headers = {"X-Custom-Header" => ["custom_value_1"]}
          request = VCR::Request.new("get", "http://any-uri.com/", nil, headers)
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("header1 response")
          end
        end
      end

      it "returns the response for header value 2 when requesting with that header" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:headers]

        VCR.use_cassette("example", options) do
          # Create a request with custom_value_2 header
          headers = {"X-Custom-Header" => ["custom_value_2"]}
          request = VCR::Request.new("get", "http://any-uri.com/", nil, headers)
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("header2 response")
          end
        end
      end

      it "matches regardless of HTTP method or URI when only :headers is specified" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:headers]

        VCR.use_cassette("example", options) do
          # The cassette has POST requests to example.com/api, but we're using GET to different.com
          # Since we only match on :headers, it should still match
          headers = {"X-Custom-Header" => ["custom_value_1"]}
          request = VCR::Request.new("get", "http://different.com/path", nil, headers)
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("header1 response")
          end
        end
      end

      it "does not match when headers differ" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:headers]

        VCR.use_cassette("example", options) do
          # Request with a header that doesn't match any in the cassette
          headers = {"X-Custom-Header" => ["different_value"]}
          request = VCR::Request.new("post", "http://example.com/api", nil, headers)
          response = VCR.http_interactions.response_for(request)

          # Should not match because headers differ
          expect(response).to be_nil
        end
      end
    end

    describe "with :method, :uri and :headers" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "matches when method, URI and headers all match" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:method, :uri, :headers]

        VCR.use_cassette("example", options) do
          # Use exact same method, URI and headers from cassette
          headers = {"X-Custom-Header" => ["custom_value_1"]}
          request = VCR::Request.new("post", "http://example.com/api", nil, headers)
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("header1 response")
          end
        end
      end

      it "does not match when URI differs" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:method, :uri, :headers]

        VCR.use_cassette("example", options) do
          # Different URI but same method and headers
          headers = {"X-Custom-Header" => ["custom_value_1"]}
          request = VCR::Request.new("post", "http://different.com/api", nil, headers)
          response = VCR.http_interactions.response_for(request)

          # Should not match because URI differs
          expect(response).to be_nil
        end
      end
    end
  end
end
