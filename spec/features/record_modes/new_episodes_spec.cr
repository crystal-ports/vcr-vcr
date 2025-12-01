require "../../spec_helper"

Spectator.describe "Record Mode: new_episodes" do
  # The :new_episodes record mode will:
  # - Record new interactions.
  # - Replay previously recorded interactions.
  #
  # Similar to :once but always records new interactions even when a cassette
  # file already exists.

  # Given a previously recorded cassette file with:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: get
      uri: http://example.com/existing
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
        - "17"
      body:
        encoding: UTF-8
        string: existing response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe ":new_episodes record mode" do
    it "is a valid record mode" do
      expect(VCR::Cassette::VALID_RECORD_MODES).to contain(:new_episodes)
    end

    it "can be set on a cassette" do
      options = VCR::CassetteOptions.new
      options[:record] = :new_episodes
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.record_mode).to eq(:new_episodes)
    end

    it "indicates the cassette is recording" do
      options = VCR::CassetteOptions.new
      options[:record] = :new_episodes
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.recording?).to be_true
    end
  end

  describe "replaying existing interactions" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("episodes", CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "replays previously recorded interactions" do
      options = VCR::CassetteOptions.new
      options[:record] = :new_episodes

      VCR.use_cassette("episodes", options) do
        request = VCR::Request.new("get", "http://example.com/existing", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(request)

        expect(response).not_to be_nil
        if resp = response
          expect(resp.body).to eq("existing response")
        end
      end
    end
  end

  describe "recording new interactions" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "allows recording when no cassette file exists" do
      options = VCR::CassetteOptions.new
      options[:record] = :new_episodes

      VCR.use_cassette("new_episodes_test", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.recording?).to be_true
        end
      end
    end

    it "allows recording new interactions to existing cassette" do
      create_cassette_file("episodes_with_new", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:record] = :new_episodes

      VCR.use_cassette("episodes_with_new", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          # :new_episodes should allow recording
          expect(c.recording?).to be_true

          # Can still replay existing
          request = VCR::Request.new("get", "http://example.com/existing", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)
          expect(response).not_to be_nil

          # And can record new interactions
          new_request = VCR::Request.new("get", "http://example.com/new", nil, {} of String => Array(String))
          new_response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "new response")
          new_interaction = VCR::HTTPInteraction.new(new_request, new_response)
          c.record_http_interaction(new_interaction)

          expect(c.new_recorded_interactions.size).to eq(1)
        end
      end
    end

    it "allows real HTTP connections for new requests" do
      create_cassette_file("allow_new", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:record] = :new_episodes

      VCR.use_cassette("allow_new", options) do
        # :new_episodes mode allows real HTTP for recording new interactions
        expect(VCR.real_http_connections_allowed?).to be_true
      end
    end
  end

  describe "difference from :once mode" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("compare", CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it ":new_episodes records when file exists, :once does not" do
      # :new_episodes allows recording even with existing file
      new_ep_options = VCR::CassetteOptions.new
      new_ep_options[:record] = :new_episodes

      VCR.use_cassette("compare", new_ep_options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.recording?).to be_true
        end
      end

      # :once does not record when file exists
      once_options = VCR::CassetteOptions.new
      once_options[:record] = :once

      VCR.use_cassette("compare", once_options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.recording?).to be_false
        end
      end
    end
  end
end
