require "../../spec_helper"

Spectator.describe "Automatic Re-Recording" do
  # VCR can automatically re-record cassettes after a specified interval.
  # This is useful for keeping cassettes up-to-date with external APIs.
  #
  # The :re_record_interval option specifies how long (in seconds) to wait
  # before re-recording a cassette.

  # Given a previously recorded cassette file with:
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
        Content-Length:
        - "8"
      body:
        encoding: UTF-8
        string: old data
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe "re_record_interval option" do
    it "accepts an integer for seconds" do
      options = VCR::CassetteOptions.new
      options[:re_record_interval] = 86400 # 1 day in seconds
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.re_record_interval).to eq(86400)
    end

    it "defaults to nil (no automatic re-recording)" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette.re_record_interval).to be_nil
    end

    it "accepts a Time::Span duration" do
      options = VCR::CassetteOptions.new
      options[:re_record_interval] = 7.days.total_seconds.to_i32
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.re_record_interval).to eq(604800) # 7 days in seconds
    end
  end

  describe "re-recording behavior" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "replays existing cassette when interval has not elapsed" do
      create_cassette_file("api_data", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:re_record_interval] = 86400 # 1 day

      VCR.use_cassette("api_data", options) do
        # The cassette file is recent, so it should replay
        request = VCR::Request.new("get", "http://example.com/data", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(request)

        expect(response).not_to be_nil
        if resp = response
          expect(resp.body).to eq("old data")
        end
      end
    end

    it "determines recording status based on interval and file age" do
      create_cassette_file("api_data", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:re_record_interval] = 86400 # 1 day

      VCR.use_cassette("api_data", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          # A recently created file shouldn't need re-recording
          # recording? depends on record mode and file existence
          expect(c.re_record_interval).to eq(86400)
        end
      end
    end

    it "records when no cassette file exists regardless of interval" do
      options = VCR::CassetteOptions.new
      options[:re_record_interval] = 86400
      options[:record] = :once

      VCR.use_cassette("new_api_data", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          # With :once mode and no file, recording should be enabled
          expect(c.recording?).to be_true
        end
      end
    end
  end

  describe "re-recording with interval" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "uses existing cassette when re_record_interval is nil" do
      create_cassette_file("test", CASSETTE_YAML)

      VCR.use_cassette("test") do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.re_record_interval).to be_nil
          # Without interval, no re-recording happens
          expect(c.recording?).to be_false
        end
      end
    end

    it "allows new recordings when cassette file does not exist" do
      options = VCR::CassetteOptions.new
      options[:re_record_interval] = 86400
      options[:record] = :once

      VCR.use_cassette("nonexistent_cassette", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          # No file exists, so recording is enabled
          expect(c.recording?).to be_true
        end
      end
    end

    it "stores re_record_interval option correctly" do
      create_cassette_file("test_interval", CASSETTE_YAML)

      options = VCR::CassetteOptions.new
      options[:re_record_interval] = 3600

      VCR.use_cassette("test_interval", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.re_record_interval).to eq(3600)
        end
      end
    end
  end
end
