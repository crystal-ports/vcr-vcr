require "../../spec_helper"

Spectator.describe "Request Matching: Identical Request Sequence" do
  # When a cassette contains multiple matching interactions,
  # responses are sequenced: first match gets first response, etc.
  #
  # This is useful when your code makes the same request multiple times
  # with different expected responses (e.g., polling).

  # Given a previously recorded cassette file with multiple identical requests:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: get
      uri: http://example.com/status
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
        - "7"
      body:
        encoding: UTF-8
        string: first
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  - request:
      method: get
      uri: http://example.com/status
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
        - "8"
      body:
        encoding: UTF-8
        string: second
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:45 GMT
  - request:
      method: get
      uri: http://example.com/status
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
        - "7"
      body:
        encoding: UTF-8
        string: third
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:46 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe "HTTPInteractionList" do
    it "maintains interaction order" do
      expect(VCR::Cassette::HTTPInteractionList::NullList.response_for(nil)).to be_nil
    end
  end

  describe "sequenced responses" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("sequence", CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "returns responses in recorded order for identical requests" do
      VCR.use_cassette("sequence") do
        request = VCR::Request.new("get", "http://example.com/status", nil, {} of String => Array(String))

        # First request gets first response
        response1 = VCR.http_interactions.response_for(request)
        expect(response1).not_to be_nil
        if resp = response1
          expect(resp.body).to eq("first")
        end

        # Second identical request gets second response
        response2 = VCR.http_interactions.response_for(request)
        expect(response2).not_to be_nil
        if resp = response2
          expect(resp.body).to eq("second")
        end

        # Third identical request gets third response
        response3 = VCR.http_interactions.response_for(request)
        expect(response3).not_to be_nil
        if resp = response3
          expect(resp.body).to eq("third")
        end

        # Fourth request - no more responses available
        response4 = VCR.http_interactions.response_for(request)
        expect(response4).to be_nil
      end
    end

    it "consumes interactions as they are used" do
      options = VCR::CassetteOptions.new
      options[:allow_unused_http_interactions] = true

      VCR.use_cassette("sequence", options) do
        request = VCR::Request.new("get", "http://example.com/status", nil, {} of String => Array(String))

        # Use only one interaction
        response = VCR.http_interactions.response_for(request)
        expect(response).not_to be_nil
        if resp = response
          expect(resp.body).to eq("first")
        end

        # Two interactions should remain unused
      end
    end
  end

  describe "different requests in sequence" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "matches each request to the correct interaction" do
      mixed_cassette = <<-YAML
      ---
      http_interactions:
      - request:
          method: get
          uri: http://example.com/a
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
            - "10"
          body:
            encoding: UTF-8
            string: response a
          http_version: "1.1"
        recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
      - request:
          method: get
          uri: http://example.com/b
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
            - "10"
          body:
            encoding: UTF-8
            string: response b
          http_version: "1.1"
        recorded_at: Tue, 01 Nov 2011 04:58:45 GMT
      recorded_with: VCR 2.0.0
      YAML

      create_cassette_file("mixed", mixed_cassette)

      VCR.use_cassette("mixed") do
        # Request B first (out of order)
        request_b = VCR::Request.new("get", "http://example.com/b", nil, {} of String => Array(String))
        response_b = VCR.http_interactions.response_for(request_b)
        expect(response_b).not_to be_nil
        if resp = response_b
          expect(resp.body).to eq("response b")
        end

        # Then request A
        request_a = VCR::Request.new("get", "http://example.com/a", nil, {} of String => Array(String))
        response_a = VCR.http_interactions.response_for(request_a)
        expect(response_a).not_to be_nil
        if resp = response_a
          expect(resp.body).to eq("response a")
        end
      end
    end
  end
end
