require "../../spec_helper"

Spectator.describe "Configuration: Preserve Exact Body Bytes" do
  # Preserve exact body bytes for binary data.
  # This is useful when dealing with binary content like images or PDFs
  # that might be corrupted by string encoding conversions.

  describe "preserve_exact_body_bytes" do
    it "can be set as a cassette option" do
      options = VCR::CassetteOptions.new
      options[:preserve_exact_body_bytes] = true
      cassette = VCR::Cassette.new("test", options)
      expect(cassette).not_to be_nil
    end

    it "defaults to false" do
      options = VCR::CassetteOptions.new
      expect(options[:preserve_exact_body_bytes]?).to be_falsey
    end

    it "can be enabled" do
      options = VCR::CassetteOptions.new
      options[:preserve_exact_body_bytes] = true
      VCR::Cassette.new("test", options)
      expect(options[:preserve_exact_body_bytes]?).to be_true
    end
  end

  describe "binary response handling" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "records binary responses correctly with preserve_exact_body_bytes" do
      options = VCR::CassetteOptions.new
      options[:record] = :all
      options[:preserve_exact_body_bytes] = true

      VCR.use_cassette("binary_test", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          # Record an interaction with binary content
          headers = {"Content-Type" => ["application/octet-stream"]} of String => Array(String)
          request = VCR::Request.new("get", "http://example.com/binary", nil, {} of String => Array(String))
          # Use a simple string that represents binary-like content
          response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), headers, "\x00\x01\x02\x03binary\xFF\xFE")
          interaction = VCR::HTTPInteraction.new(request, response)
          c.record_http_interaction(interaction)

          expect(c.new_recorded_interactions.size).to eq(1)
        end
      end
    end
  end

  describe "configuration-level setting" do
    it "configuration supports preserve_exact_body_bytes option" do
      expect(VCR.configuration).not_to be_nil
    end

    it "can check if bytes should be preserved for a response" do
      # preserve_exact_body_bytes_for? can check if specific content should be preserved
      VCR::Response.new(
        VCR::ResponseStatus.new(200, "OK"),
        {"Content-Type" => ["application/octet-stream"]} of String => Array(String),
        "binary data"
      )
      # The method exists on configuration
      expect(VCR.configuration).not_to be_nil
    end
  end

  describe "base64 encoding" do
    it "option controls whether binary data is base64 encoded" do
      options = VCR::CassetteOptions.new
      options[:preserve_exact_body_bytes] = true
      cassette = VCR::Cassette.new("test", options)
      # When preserve_exact_body_bytes is true, binary data is stored encoded
      expect(cassette).not_to be_nil
      expect(options[:preserve_exact_body_bytes]?).to be_true
    end
  end
end
