require "../../spec_helper"

Spectator.describe "Record Mode: once" do
  # The :once record mode will:
  # - Replay previously recorded interactions.
  # - Record new interactions if there is no cassette file.
  # - Cause an error for new requests if there is a cassette file.
  #
  # :once is the default record mode. It is designed to be the simplest
  # option that works well for the majority of use cases.

  # Given a previously recorded cassette file "cassettes/example.yml" with:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: get
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
        - "18"
      body:
        encoding: UTF-8
        string: existing response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe ":once record mode" do
    it "is a valid record mode" do
      expect(VCR::Cassette::VALID_RECORD_MODES).to contain(:once)
    end

    it "is the default record mode" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette.record_mode).to eq(:once)
    end

    it "can be set explicitly on a cassette" do
      options = VCR::CassetteOptions.new
      options[:record] = :once
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.record_mode).to eq(:once)
    end

    describe "replaying previously recorded responses" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "replays responses from the cassette" do
        options = VCR::CassetteOptions.new
        options[:record] = :once

        VCR.use_cassette("example", options) do
          # Create a request that matches the cassette
          request = VCR::Request.new("get", "http://example.com/foo", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("existing response")
          end
        end
      end
    end

    describe "recording behavior" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "indicates recording is possible when no cassette file exists" do
        options = VCR::CassetteOptions.new
        options[:record] = :once

        VCR.use_cassette("new_cassette", options) do
          cassette = VCR.current_cassette
          expect(cassette).not_to be_nil
          if c = cassette
            # :once mode records if file doesn't exist
            expect(c.recording?).to be_true
          end
        end
      end

      it "does not record when cassette file already exists" do
        # Create the cassette file first
        create_cassette_file("existing_cassette", CASSETTE_YAML)

        options = VCR::CassetteOptions.new
        options[:record] = :once

        VCR.use_cassette("existing_cassette", options) do
          cassette = VCR.current_cassette
          expect(cassette).not_to be_nil
          if c = cassette
            # :once mode doesn't record if file exists
            expect(c.recording?).to be_false
          end
        end
      end
    end

    describe "handling unmatched requests" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "returns nil for requests not in the cassette when file exists" do
        options = VCR::CassetteOptions.new
        options[:record] = :once

        VCR.use_cassette("example", options) do
          # Create a request for a different URI not in the cassette
          request = VCR::Request.new("get", "http://example.com/bar", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # In :once mode with existing file, unmatched requests return nil
          expect(response).to be_nil
        end
      end

      it "does not allow real http connections when cassette exists" do
        options = VCR::CassetteOptions.new
        options[:record] = :once

        VCR.use_cassette("example", options) do
          # With :once mode and existing cassette, real connections shouldn't be allowed
          expect(VCR.real_http_connections_allowed?).to be_false
        end
      end
    end
  end
end
