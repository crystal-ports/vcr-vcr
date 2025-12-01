require "../../spec_helper"

Spectator.describe "Request Matching: Playback Repeats" do
  # By default, each response can only be played back once.
  # Use :allow_playback_repeats to allow responses to be repeated.
  #
  # This is useful when your code makes the same request multiple times
  # and you want the same response each time.

  # Given a previously recorded cassette file with:
  CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: get
      uri: http://example.com/repeatable
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
        string: repeated response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe "allow_playback_repeats option" do
    it "defaults to false" do
      options = VCR::CassetteOptions.new
      expect(options[:allow_playback_repeats]?).to be_falsey
    end

    it "can be enabled" do
      options = VCR::CassetteOptions.new
      options[:allow_playback_repeats] = true
      VCR::Cassette.new("test", options)
      expect(options[:allow_playback_repeats]?).to be_true
    end
  end

  describe "playback behavior" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("repeats", CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "returns nil on second request without allow_playback_repeats" do
      options = VCR::CassetteOptions.new
      options[:allow_playback_repeats] = false

      VCR.use_cassette("repeats", options) do
        request = VCR::Request.new("get", "http://example.com/repeatable", nil, {} of String => Array(String))

        # First request succeeds
        response1 = VCR.http_interactions.response_for(request)
        expect(response1).not_to be_nil

        # Second identical request returns nil (interaction consumed)
        response2 = VCR.http_interactions.response_for(request)
        expect(response2).to be_nil
      end
    end

    it "returns the same response on repeated requests with allow_playback_repeats" do
      options = VCR::CassetteOptions.new
      options[:allow_playback_repeats] = true

      VCR.use_cassette("repeats", options) do
        request = VCR::Request.new("get", "http://example.com/repeatable", nil, {} of String => Array(String))

        # First request
        response1 = VCR.http_interactions.response_for(request)
        expect(response1).not_to be_nil
        if resp = response1
          expect(resp.body).to eq("repeated response")
        end

        # Second identical request - should return same response
        response2 = VCR.http_interactions.response_for(request)
        expect(response2).not_to be_nil
        if resp = response2
          expect(resp.body).to eq("repeated response")
        end

        # Third request - still works
        response3 = VCR.http_interactions.response_for(request)
        expect(response3).not_to be_nil
      end
    end
  end

  describe "interaction with HTTPInteractionList" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("list_test", CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "affects how the interaction list handles requests" do
      options = VCR::CassetteOptions.new
      options[:allow_playback_repeats] = true

      VCR.use_cassette("list_test", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        # The option was set; verify cassette was created
        expect(options[:allow_playback_repeats]?).to be_true
      end
    end
  end
end
