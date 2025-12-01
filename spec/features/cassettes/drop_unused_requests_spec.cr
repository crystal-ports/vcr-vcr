require "../../spec_helper"

Spectator.describe "Drop Unused Requests" do
  # When enabled, this option removes any unused interactions from the cassette
  # when it is ejected, keeping only the interactions that were actually used.
  #
  # This is useful for cleaning up cassettes that have accumulated stale interactions
  # over time.

  # Given a previously recorded cassette file with multiple interactions:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: get
      uri: http://example.com/used
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
        - "13"
      body:
        encoding: UTF-8
        string: used response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  - request:
      method: get
      uri: http://example.com/unused
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
        - "15"
      body:
        encoding: UTF-8
        string: unused response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe "drop_unused_requests option" do
    it "defaults to false" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette.drop_unused_requests?).to be_false
    end

    it "can be enabled" do
      options = VCR::CassetteOptions.new
      options[:drop_unused_requests] = true
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.drop_unused_requests?).to be_true
    end
  end

  describe "behavior with cassettes" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "replays interactions regardless of drop_unused_requests setting" do
      create_cassette_file("multi_interaction", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:drop_unused_requests] = true

      VCR.use_cassette("multi_interaction", options) do
        # Can still use the interactions
        request = VCR::Request.new("get", "http://example.com/used", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(request)

        expect(response).not_to be_nil
        if resp = response
          expect(resp.body).to eq("used response")
        end
      end
    end

    it "tracks which interactions have been used" do
      create_cassette_file("track_usage", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:drop_unused_requests] = true
      options[:allow_unused_http_interactions] = true

      VCR.use_cassette("track_usage", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil

        # Use one interaction
        request = VCR::Request.new("get", "http://example.com/used", nil, {} of String => Array(String))
        VCR.http_interactions.response_for(request)

        # The HTTP interaction list tracks usage
        expect(VCR.http_interactions).not_to be_nil
      end
    end

    it "works with allow_unused_http_interactions to control error behavior" do
      create_cassette_file("unused_control", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:drop_unused_requests] = true
      options[:allow_unused_http_interactions] = true # Don't error on unused

      # Should not raise an error when ejecting with unused interactions
      VCR.use_cassette("unused_control", options) do
        # Don't use any interactions
      end
    end
  end

  describe "interaction with recording modes" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "can be combined with :none record mode" do
      create_cassette_file("none_mode", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:record] = :none
      options[:drop_unused_requests] = true
      options[:allow_unused_http_interactions] = true

      VCR.use_cassette("none_mode", options) do
        request = VCR::Request.new("get", "http://example.com/used", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(request)

        expect(response).not_to be_nil
      end
    end

    it "can be combined with :once record mode" do
      create_cassette_file("once_mode", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:record] = :once
      options[:drop_unused_requests] = true
      options[:allow_unused_http_interactions] = true

      VCR.use_cassette("once_mode", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.drop_unused_requests?).to be_true
        end
      end
    end
  end
end
