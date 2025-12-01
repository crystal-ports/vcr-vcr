require "../../spec_helper"

Spectator.describe "Configuration: Query Parser" do
  # Configure custom query string parsing.
  # VCR uses this to parse query strings for the :query matcher.

  # Clean up query_parser after each test to prevent state pollution
  after_each do
    VCR.configuration.query_parser = nil
  end

  describe "query_parser" do
    it "is configurable" do
      expect(VCR.configuration).not_to be_nil
    end

    it "can set a custom query parser" do
      VCR.configuration.query_parser = ->(query : String) {
        result = {} of String => Array(String)
        HTTP::Params.parse(query).each do |key, value|
          result[key] ||= [] of String
          result[key] << value
        end
        result
      }
      expect(VCR.configuration.query_parser).not_to be_nil
    end
  end

  describe "default query parsing" do
    it "parses simple query strings" do
      uri = URI.parse("http://example.com/path?foo=bar&baz=qux")
      query = uri.query || ""
      params = HTTP::Params.parse(query)

      expect(params["foo"]?).to eq("bar")
      expect(params["baz"]?).to eq("qux")
    end

    it "handles URL-encoded values" do
      uri = URI.parse("http://example.com/path?name=John%20Doe&email=test%40example.com")
      query = uri.query || ""
      params = HTTP::Params.parse(query)

      expect(params["name"]?).to eq("John Doe")
      expect(params["email"]?).to eq("test@example.com")
    end

    it "handles empty query strings" do
      uri = URI.parse("http://example.com/path")
      query = uri.query || ""
      params = HTTP::Params.parse(query)

      expect(params.to_h.empty?).to be_true
    end
  end

  describe "query matching" do
    CASSETTE_YAML = <<-YAML
    ---
    http_interactions:
    - request:
        method: get
        uri: http://api.example.com/search?q=test&page=1
        body:
          encoding: UTF-8
          string: ""
        headers: {}
      response:
        status:
          code: 200
          message: OK
        headers: {}
        body:
          encoding: UTF-8
          string: "search results"
        http_version: "1.1"
      recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
    recorded_with: VCR 2.0.0
    YAML

    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("query_test", CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "matches requests with same query parameters" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:method, :host, :path, :query]

      VCR.use_cassette("query_test", options) do
        # Same query params
        request = VCR::Request.new("get", "http://api.example.com/search?q=test&page=1", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(request)

        expect(response).not_to be_nil
        if resp = response
          expect(resp.body).to eq("search results")
        end
      end
    end

    it "matches requests with query params in different order when query_parser is configured" do
      # Configure a query parser that normalizes query params for order-independent matching
      VCR.configuration.query_parser = ->(query : String) {
        result = {} of String => Array(String)
        HTTP::Params.parse(query).each do |key, value|
          result[key] ||= [] of String
          result[key] << value
        end
        result
      }

      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:method, :host, :path, :query]

      VCR.use_cassette("query_test", options) do
        # Query params in different order should match with query_parser configured
        request = VCR::Request.new("get", "http://api.example.com/search?page=1&q=test", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(request)

        expect(response).not_to be_nil
      end
    end
  end
end
