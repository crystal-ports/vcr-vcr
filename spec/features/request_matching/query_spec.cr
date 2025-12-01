require "../../spec_helper"

Spectator.describe "Request Matching: Query" do
  # Use :query to match requests on the query string portion of the URI.
  #
  # This is useful when you want to match requests based on query parameters
  # while ignoring other parts of the URI.

  # Given a previously recorded cassette file "cassettes/example.yml" with:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: get
      uri: http://example.com/api?user_id=1&page=1
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
        - "14"
      body:
        encoding: UTF-8
        string: query1 response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  - request:
      method: get
      uri: http://example.com/api?user_id=2&page=1
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
        - "14"
      body:
        encoding: UTF-8
        string: query2 response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe ":query matcher" do
    it "is a registered matcher" do
      expect(VCR.request_matchers[:query]).not_to be_nil
    end

    it "can be used in match_requests_on" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:query]
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.match_requests_on).to contain(:query)
    end

    describe "replay interaction that matches the query string" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "returns the response for query with user_id=1" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:query]

        VCR.use_cassette("example", options) do
          # Create a request with same query params
          request = VCR::Request.new("get", "http://any-host.com/any-path?user_id=1&page=1", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("query1 response")
          end
        end
      end

      it "returns the response for query with user_id=2" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:query]

        VCR.use_cassette("example", options) do
          # Create a request with same query params
          request = VCR::Request.new("get", "http://any-host.com/any-path?user_id=2&page=1", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("query2 response")
          end
        end
      end

      it "matches regardless of HTTP method, host or path when only :query is specified" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:query]

        VCR.use_cassette("example", options) do
          # The cassette has GET requests to example.com/api, but we're using POST to different.com/different
          # Since we only match on :query, it should still match
          request = VCR::Request.new("post", "http://different.com/different?user_id=1&page=1", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("query1 response")
          end
        end
      end

      it "does not match when query params are in different order (without query_parser)" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:query]

        VCR.use_cassette("example", options) do
          # Without a query_parser configured, query comparison is done by string comparison
          # so different param order won't match
          request = VCR::Request.new("get", "http://example.com/api?page=1&user_id=1", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # Should not match because query string order differs
          # (Configure a query_parser for order-independent matching)
          expect(response).to be_nil
        end
      end

      it "does not match when query params differ" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:query]

        VCR.use_cassette("example", options) do
          # Request with different query params
          request = VCR::Request.new("get", "http://example.com/api?user_id=99&page=1", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # Should not match because query params differ
          expect(response).to be_nil
        end
      end

      it "does not match when query params are missing" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:query]

        VCR.use_cassette("example", options) do
          # Request with no query params
          request = VCR::Request.new("get", "http://example.com/api", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # Should not match because query is empty
          expect(response).to be_nil
        end
      end
    end

    describe "with :method, :host and :query" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "matches when method, host and query all match" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:method, :host, :query]

        VCR.use_cassette("example", options) do
          # Same method and host, same query, different path
          request = VCR::Request.new("get", "http://example.com/different/path?user_id=1&page=1", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("query1 response")
          end
        end
      end

      it "does not match when host differs" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:method, :host, :query]

        VCR.use_cassette("example", options) do
          # Different host but same method and query
          request = VCR::Request.new("get", "http://different.com/api?user_id=1&page=1", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # Should not match because host differs
          expect(response).to be_nil
        end
      end
    end
  end
end
