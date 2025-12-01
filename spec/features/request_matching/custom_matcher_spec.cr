require "../../spec_helper"

Spectator.describe "Request Matching: Custom Matcher" do
  # Custom matchers can be registered and used in match_requests_on.
  # You can create matchers that apply custom logic to request matching.

  # Given a cassette with API version in header:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: get
      uri: http://api.example.com/data
      body:
        encoding: UTF-8
        string: ""
      headers:
        X-Api-Version:
        - "v2"
    response:
      status:
        code: 200
        message: OK
      headers:
        Content-Type:
        - "application/json"
      body:
        encoding: UTF-8
        string: '{"version":"v2","data":"response"}'
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe "RequestMatcherRegistry" do
    it "allows registering custom matchers" do
      expect(VCR.request_matchers).not_to be_nil
    end

    it "provides access to registered matchers" do
      expect(VCR.request_matchers[:method]).not_to be_nil
      expect(VCR.request_matchers[:uri]).not_to be_nil
    end

    it "provides access to built-in matchers" do
      expect(VCR.request_matchers[:body]).not_to be_nil
      expect(VCR.request_matchers[:headers]).not_to be_nil
      expect(VCR.request_matchers[:host]).not_to be_nil
      expect(VCR.request_matchers[:path]).not_to be_nil
      expect(VCR.request_matchers[:query]).not_to be_nil
    end
  end

  describe "registering custom matchers" do
    it "can register a custom matcher with a proc" do
      # Register a custom matcher that only matches on specific header
      VCR.request_matchers.register(:api_version) do |request1, request2|
        request1.headers["X-Api-Version"]? == request2.headers["X-Api-Version"]?
      end

      expect(VCR.request_matchers[:api_version]).not_to be_nil
    end
  end

  describe "using custom matchers" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("api_versioned", CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "can use custom matchers in match_requests_on" do
      # Register a matcher that checks a custom header
      VCR.request_matchers.register(:x_api_version) do |request1, request2|
        request1.headers["X-Api-Version"]? == request2.headers["X-Api-Version"]?
      end

      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:method, :uri, :x_api_version]

      VCR.use_cassette("api_versioned", options) do
        # Request with matching version
        headers = {"X-Api-Version" => ["v2"]} of String => Array(String)
        request = VCR::Request.new("get", "http://api.example.com/data", nil, headers)

        response = VCR.http_interactions.response_for(request)
        expect(response).not_to be_nil
        if resp = response
          expect(resp.body).to contain("v2")
        end
      end
    end

    it "custom matcher returns nil when no match" do
      VCR.request_matchers.register(:x_api_version_check) do |request1, request2|
        request1.headers["X-Api-Version"]? == request2.headers["X-Api-Version"]?
      end

      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:method, :uri, :x_api_version_check]

      VCR.use_cassette("api_versioned", options) do
        # Request with different version
        headers = {"X-Api-Version" => ["v3"]} of String => Array(String)
        request = VCR::Request.new("get", "http://api.example.com/data", nil, headers)

        response = VCR.http_interactions.response_for(request)
        expect(response).to be_nil
      end
    end
  end

  describe "matcher proc behavior" do
    it "matcher receives both requests to compare" do
      called = false
      received_requests = [] of VCR::Request

      VCR.request_matchers.register(:tracking_matcher) do |request1, request2|
        called = true
        received_requests << request1
        received_requests << request2
        true # Always match
      end

      matcher = VCR.request_matchers[:tracking_matcher]
      expect(matcher).not_to be_nil

      if m = matcher
        headers = {} of String => Array(String)
        req1 = VCR::Request.new("get", "http://example.com/a", nil, headers)
        req2 = VCR::Request.new("get", "http://example.com/b", nil, headers)

        result = m.matches?(req1, req2)
        expect(result).to be_true
        expect(called).to be_true
        expect(received_requests.size).to eq(2)
      end
    end
  end
end
