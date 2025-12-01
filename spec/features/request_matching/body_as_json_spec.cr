require "../../spec_helper"

Spectator.describe "Request Matching: Body as JSON" do
  # Use :body_as_json to match requests on JSON request body.
  # This matcher parses JSON and compares the data structures,
  # so key order and whitespace differences don't matter.

  # Given a cassette with a JSON request body:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: post
      uri: http://api.example.com/users
      body:
        encoding: UTF-8
        string: '{"name":"John","age":30}'
      headers:
        Content-Type:
        - "application/json"
    response:
      status:
        code: 201
        message: Created
      headers:
        Content-Type:
        - "application/json"
      body:
        encoding: UTF-8
        string: '{"id":1,"name":"John","age":30}'
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe ":body_as_json matcher" do
    it "is a registered matcher" do
      expect(VCR.request_matchers[:body_as_json]).not_to be_nil
    end

    it "can be used in match_requests_on" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:body_as_json]
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.match_requests_on).to contain(:body_as_json)
    end

    it "returns a matcher proc" do
      matcher = VCR.request_matchers[:body_as_json]
      expect(matcher).not_to be_nil
    end
  end

  describe "matching behavior" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("json_body", CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "matches when JSON bodies are structurally equivalent" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:method, :uri, :body_as_json]

      VCR.use_cassette("json_body", options) do
        # Same JSON but with different key order
        headers = {"Content-Type" => ["application/json"]} of String => Array(String)
        request = VCR::Request.new("post", "http://api.example.com/users", "{\"age\":30,\"name\":\"John\"}", headers)

        response = VCR.http_interactions.response_for(request)
        expect(response).not_to be_nil
        if resp = response
          expect(resp.status.code).to eq(201)
        end
      end
    end

    it "does not match when JSON bodies differ" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:method, :uri, :body_as_json]

      VCR.use_cassette("json_body", options) do
        # Different JSON body
        headers = {"Content-Type" => ["application/json"]} of String => Array(String)
        request = VCR::Request.new("post", "http://api.example.com/users", "{\"name\":\"Jane\",\"age\":25}", headers)

        response = VCR.http_interactions.response_for(request)
        expect(response).to be_nil
      end
    end
  end

  describe "matcher logic" do
    it "parses and compares JSON structures" do
      matcher = VCR.request_matchers[:body_as_json]
      expect(matcher).not_to be_nil

      if m = matcher
        headers = {} of String => Array(String)
        # Same data, different formatting
        request1 = VCR::Request.new("post", "http://example.com", "{\"a\":1,\"b\":2}", headers)
        request2 = VCR::Request.new("post", "http://example.com", "{\"b\":2,\"a\":1}", headers)

        expect(m.matches?(request1, request2)).to be_true
      end
    end

    it "returns false for different JSON" do
      matcher = VCR.request_matchers[:body_as_json]
      expect(matcher).not_to be_nil

      if m = matcher
        headers = {} of String => Array(String)
        request1 = VCR::Request.new("post", "http://example.com", "{\"a\":1}", headers)
        request2 = VCR::Request.new("post", "http://example.com", "{\"a\":2}", headers)

        expect(m.matches?(request1, request2)).to be_false
      end
    end

    it "handles nil bodies" do
      matcher = VCR.request_matchers[:body_as_json]
      expect(matcher).not_to be_nil

      if m = matcher
        headers = {} of String => Array(String)
        request1 = VCR::Request.new("get", "http://example.com", nil, headers)
        request2 = VCR::Request.new("get", "http://example.com", nil, headers)

        expect(m.matches?(request1, request2)).to be_true
      end
    end

    it "handles empty bodies" do
      matcher = VCR.request_matchers[:body_as_json]
      expect(matcher).not_to be_nil

      if m = matcher
        headers = {} of String => Array(String)
        request1 = VCR::Request.new("get", "http://example.com", "", headers)
        request2 = VCR::Request.new("get", "http://example.com", "", headers)

        expect(m.matches?(request1, request2)).to be_true
      end
    end
  end
end
