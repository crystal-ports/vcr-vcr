require "../../spec_helper"

Spectator.describe "Configuration: Default Cassette Options" do
  # Set default options that apply to all cassettes.
  # These defaults can be overridden on a per-cassette basis.

  describe "default_cassette_options" do
    it "can be configured" do
      expect(VCR.configuration.default_cassette_options).to be_a(VCR::CassetteOptions)
    end

    it "defaults match_requests_on to [:method, :uri]" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette.match_requests_on).to eq([:method, :uri])
    end

    it "defaults record mode to :once" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette.record_mode).to eq(:once)
    end

    it "returns a CassetteOptions instance" do
      expect(VCR.configuration.default_cassette_options).to be_a(VCR::CassetteOptions)
    end
  end

  describe "configuring defaults" do
    it "can change default record mode" do
      defaults = VCR.configuration.default_cassette_options
      original_record = defaults[:record]?

      defaults[:record] = :new_episodes
      expect(defaults[:record]?).to eq(:new_episodes)

      # Reset to original
      defaults[:record] = original_record || :once
    end

    it "can change default match_requests_on" do
      defaults = VCR.configuration.default_cassette_options
      original_matchers = defaults[:match_requests_on]?

      defaults[:match_requests_on] = [:method, :uri, :body]
      expect(defaults[:match_requests_on]?).to eq([:method, :uri, :body])

      # Reset to original
      defaults[:match_requests_on] = original_matchers || [:method, :uri]
    end
  end

  describe "option inheritance" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "cassettes inherit from default options" do
      defaults = VCR.configuration.default_cassette_options
      defaults[:allow_playback_repeats] = true

      VCR.use_cassette("inherit_test") do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
      end

      # Reset
      defaults[:allow_playback_repeats] = false
    end

    it "per-cassette options override defaults" do
      defaults = VCR.configuration.default_cassette_options
      defaults[:record] = :once

      options = VCR::CassetteOptions.new
      options[:record] = :all

      VCR.use_cassette("override_test", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.record_mode).to eq(:all)
        end
      end
    end
  end

  describe "available options" do
    it "supports record option" do
      options = VCR::CassetteOptions.new
      options[:record] = :none
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.record_mode).to eq(:none)
    end

    it "supports match_requests_on option" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:method, :host, :path]
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.match_requests_on).to eq([:method, :host, :path])
    end

    it "supports allow_playback_repeats option" do
      options = VCR::CassetteOptions.new
      options[:allow_playback_repeats] = true
      cassette = VCR::Cassette.new("test", options)
      expect(cassette).not_to be_nil
      expect(options[:allow_playback_repeats]?).to be_true
    end

    it "supports serialize_with option" do
      options = VCR::CassetteOptions.new
      options[:serialize_with] = :json
      cassette = VCR::Cassette.new("test", options)
      file = cassette.file
      expect(file).not_to be_nil
      if f = file
        expect(f).to end_with(".json")
      end
    end

    it "supports decode_compressed_response option" do
      options = VCR::CassetteOptions.new
      options[:decode_compressed_response] = true
      cassette = VCR::Cassette.new("test", options)
      expect(cassette).not_to be_nil
      expect(options[:decode_compressed_response]?).to be_true
    end
  end
end
