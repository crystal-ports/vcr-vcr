require "../../spec_helper"

Spectator.describe "Record Mode: all" do
  # The :all record mode will:
  # - Record new interactions.
  # - Never replay previously recorded interactions.
  #
  # This can be used to force VCR to re-record a cassette
  # (i.e. to ensure the responses are not out of date)
  # or when you want to log all HTTP requests.

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
        - "20"
      body:
        encoding: UTF-8
        string: old recorded response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe ":all record mode" do
    it "is a valid record mode" do
      expect(VCR::Cassette::VALID_RECORD_MODES).to contain(:all)
    end

    it "can be set on a cassette" do
      options = VCR::CassetteOptions.new
      options[:record] = :all
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.record_mode).to eq(:all)
    end

    it "indicates the cassette is recording" do
      options = VCR::CassetteOptions.new
      options[:record] = :all
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.recording?).to be_true
    end

    describe "recording behavior" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "always records, even when cassette file already exists" do
        # Create the cassette file first
        create_cassette_file("example", CASSETTE_YAML)

        options = VCR::CassetteOptions.new
        options[:record] = :all

        VCR.use_cassette("example", options) do
          cassette = VCR.current_cassette
          expect(cassette).not_to be_nil
          if c = cassette
            # :all mode always records
            expect(c.recording?).to be_true
          end
        end
      end

      it "allows recording new interactions" do
        options = VCR::CassetteOptions.new
        options[:record] = :all

        VCR.use_cassette("new_recording", options) do
          cassette = VCR.current_cassette
          expect(cassette).not_to be_nil
          if c = cassette
            expect(c.new_recorded_interactions.size).to eq(0)

            # Record a new interaction
            request = VCR::Request.new("get", "http://example.com/test", nil, {} of String => Array(String))
            response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "test body")
            interaction = VCR::HTTPInteraction.new(request, response)
            c.record_http_interaction(interaction)

            expect(c.new_recorded_interactions.size).to eq(1)
          end
        end
      end
    end

    describe "playback behavior" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "does not replay previously recorded interactions" do
        options = VCR::CassetteOptions.new
        options[:record] = :all

        VCR.use_cassette("example", options) do
          # In :all mode, existing interactions are not replayed
          # (they will be overwritten when re-recording)
          request = VCR::Request.new("get", "http://example.com/foo", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # The response should be nil because :all mode doesn't replay
          expect(response).to be_nil
        end
      end

      it "allows real http connections" do
        options = VCR::CassetteOptions.new
        options[:record] = :all

        VCR.use_cassette("example", options) do
          # :all mode allows real HTTP connections for recording
          expect(VCR.real_http_connections_allowed?).to be_true
        end
      end
    end
  end
end
