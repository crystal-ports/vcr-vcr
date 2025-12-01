require "../../spec_helper"

Spectator.describe VCR::Configuration do
  # Note: Many Configuration methods modify GLOBAL VCR state.
  # We save and restore state to avoid polluting other tests.

  describe "#cassette_library_dir=" do
    it "sets the cassette library directory" do
      original_dir = VCR.configuration.cassette_library_dir
      begin
        config = VCR::Configuration.new
        config.cassette_library_dir = "/tmp/test_cassettes"
        expect(config.cassette_library_dir).to eq("/tmp/test_cassettes")
      ensure
        VCR.configuration.cassette_library_dir = original_dir
      end
    end
  end

  describe "#default_cassette_options" do
    it "has sensible defaults" do
      config = VCR::Configuration.new
      options = config.default_cassette_options
      expect(options[:record]?).to eq(:once)
      expect(options[:match_requests_on]?).to eq([:method, :uri])
    end

    # Note: This test modifies the global default cassette options
    # but that's an instance variable, not a global, so it's OK
    it "allows defaults to be overridden" do
      config = VCR::Configuration.new
      config.default_cassette_options = {:record => :all}
      expect(config.default_cassette_options[:record]?).to eq(:all)
    end
  end

  describe "#ignore_hosts" do
    it "delegates to request_ignorer" do
      config = VCR::Configuration.new
      # Note: This modifies global VCR.request_ignorer
      # The ignore_hosts functionality can be unignored with unignore_hosts
      config.ignore_hosts("test-example.com")
      config.unignore_hosts("test-example.com")
    end
  end

  describe "#ignore_localhost=" do
    it "can be set to true" do
      config = VCR::Configuration.new
      # Note: This modifies global VCR.request_ignorer
      config.ignore_localhost = true
      # Reset it back
      config.ignore_localhost = false
    end
  end

  describe "#allow_http_connections_when_no_cassette=" do
    it "sets the flag" do
      config = VCR::Configuration.new
      original = config.allow_http_connections_when_no_cassette?
      begin
        config.allow_http_connections_when_no_cassette = true
        expect(config.allow_http_connections_when_no_cassette?).to be_true
      ensure
        config.allow_http_connections_when_no_cassette = original
      end
    end

    it "defaults to false" do
      config = VCR::Configuration.new
      expect(config.allow_http_connections_when_no_cassette?).to be_false
    end
  end

  describe "#uri_parser" do
    it "defaults to URI" do
      config = VCR::Configuration.new
      expect(config.uri_parser).to eq(URI)
    end
  end

  describe "#debug_logger=" do
    it "can be set to an IO" do
      config = VCR::Configuration.new
      original_logger = config.debug_logger
      begin
        config.debug_logger = STDERR
        # No error should be raised
      ensure
        config.debug_logger = original_logger
      end
    end
  end

  describe "#register_request_matcher" do
    it "registers a custom matcher" do
      # Note: This modifies global VCR.request_matchers
      # We use a unique name that won't conflict with built-in matchers
      config = VCR::Configuration.new
      config.register_request_matcher(:test_custom_matcher) { |r1, r2| true }
      # The matcher should be registered in VCR.request_matchers
      expect(VCR.request_matchers[:test_custom_matcher]).not_to be_nil
    end
  end
end
