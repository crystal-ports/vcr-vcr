require "../../spec_helper"

Spectator.describe "Decompress Response" do
  # VCR can decode compressed responses before recording the cassette.
  # This makes cassettes more human-readable.

  describe "decode_compressed_response option" do
    it "can be enabled via cassette options" do
      options = VCR::CassetteOptions.new
      options[:decode_compressed_response] = true
      cassette = VCR::Cassette.new("test", options)
      expect(cassette).not_to be_nil
    end

    it "option can be set to true" do
      options = VCR::CassetteOptions.new
      options[:decode_compressed_response] = true
      expect(options[:decode_compressed_response]?).to be_true
    end

    it "option can be set to false" do
      options = VCR::CassetteOptions.new
      options[:decode_compressed_response] = false
      expect(options[:decode_compressed_response]?).to be_false
    end
  end

  describe "recording compressed responses" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "stores compressed responses when decode_compressed_response is false" do
      options = VCR::CassetteOptions.new
      options[:record] = :all
      options[:decode_compressed_response] = false

      VCR.use_cassette("compressed_test", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          # Record an interaction with Content-Encoding header
          headers = {"Content-Encoding" => ["gzip"]} of String => Array(String)
          request = VCR::Request.new("get", "http://example.com/compressed", nil, {} of String => Array(String))
          response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), headers, "compressed_body")
          interaction = VCR::HTTPInteraction.new(request, response)
          c.record_http_interaction(interaction)

          # Response body is stored as-is
          expect(c.new_recorded_interactions.size).to eq(1)
        end
      end
    end

    it "can record interactions when decode_compressed_response is true" do
      options = VCR::CassetteOptions.new
      options[:record] = :all
      options[:decode_compressed_response] = true

      VCR.use_cassette("decompress_test", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          # Record an interaction
          request = VCR::Request.new("get", "http://example.com/plain", nil, {} of String => Array(String))
          response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "plain_body")
          interaction = VCR::HTTPInteraction.new(request, response)
          c.record_http_interaction(interaction)

          expect(c.new_recorded_interactions.size).to eq(1)
        end
      end
    end
  end

  describe "playback with compression headers" do
    # Given a cassette with a response that has Content-Encoding header
    CASSETTE_YAML = <<-YAML
    ---
    http_interactions:
    - request:
        method: get
        uri: http://example.com/data
        body:
          encoding: UTF-8
          string: ""
        headers: {}
      response:
        status:
          code: 200
          message: OK
        headers:
          Content-Encoding:
          - "gzip"
          Content-Type:
          - "application/json"
        body:
          encoding: UTF-8
          string: "response data"
        http_version: "1.1"
      recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
    recorded_with: VCR 2.0.0
    YAML

    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("with_encoding", CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "plays back response with original headers" do
      VCR.use_cassette("with_encoding") do
        request = VCR::Request.new("get", "http://example.com/data", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(request)

        expect(response).not_to be_nil
        if resp = response
          expect(resp.body).to eq("response data")
          expect(resp.headers["Content-Encoding"]?).to eq(["gzip"])
        end
      end
    end
  end
end
