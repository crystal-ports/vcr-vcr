require "../../spec_helper"

Spectator.describe "Configuration: allow_http_connections_when_no_cassette" do
  # Allow HTTP requests when no cassette is in use.
  # By default, VCR will raise an error if an HTTP request is made without a cassette.
  # This option allows you to bypass VCR when no cassette is in use.

  describe "allow_http_connections_when_no_cassette" do
    it "can be enabled" do
      original = VCR.configuration.allow_http_connections_when_no_cassette?
      VCR.configuration.allow_http_connections_when_no_cassette = true
      expect(VCR.real_http_connections_allowed?).to be_true
      VCR.configuration.allow_http_connections_when_no_cassette = original
    end

    it "can be disabled" do
      original = VCR.configuration.allow_http_connections_when_no_cassette?
      VCR.configuration.allow_http_connections_when_no_cassette = false
      expect(VCR.real_http_connections_allowed?).to be_false
      VCR.configuration.allow_http_connections_when_no_cassette = original
    end

    it "can be queried" do
      original = VCR.configuration.allow_http_connections_when_no_cassette?

      VCR.configuration.allow_http_connections_when_no_cassette = true
      expect(VCR.configuration.allow_http_connections_when_no_cassette?).to be_true

      VCR.configuration.allow_http_connections_when_no_cassette = false
      expect(VCR.configuration.allow_http_connections_when_no_cassette?).to be_false

      VCR.configuration.allow_http_connections_when_no_cassette = original
    end
  end

  describe "effect on VCR.real_http_connections_allowed?" do
    it "allows HTTP when no cassette and option is true" do
      original = VCR.configuration.allow_http_connections_when_no_cassette?
      # Ensure no cassette is in use
      expect(VCR.current_cassette).to be_nil

      VCR.configuration.allow_http_connections_when_no_cassette = true
      expect(VCR.real_http_connections_allowed?).to be_true

      VCR.configuration.allow_http_connections_when_no_cassette = original
    end

    it "blocks HTTP when no cassette and option is false" do
      original = VCR.configuration.allow_http_connections_when_no_cassette?
      # Ensure no cassette is in use
      expect(VCR.current_cassette).to be_nil

      VCR.configuration.allow_http_connections_when_no_cassette = false
      expect(VCR.real_http_connections_allowed?).to be_false

      VCR.configuration.allow_http_connections_when_no_cassette = original
    end
  end

  describe "interaction with cassettes" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "cassette record mode takes precedence when cassette is in use" do
      original = VCR.configuration.allow_http_connections_when_no_cassette?
      VCR.configuration.allow_http_connections_when_no_cassette = false

      options = VCR::CassetteOptions.new
      options[:record] = :all # This should allow HTTP

      VCR.use_cassette("http_test", options) do
        expect(VCR.real_http_connections_allowed?).to be_true
      end

      VCR.configuration.allow_http_connections_when_no_cassette = original
    end

    it ":none record mode blocks HTTP even when allow_http_connections is true" do
      original = VCR.configuration.allow_http_connections_when_no_cassette?
      VCR.configuration.allow_http_connections_when_no_cassette = true

      options = VCR::CassetteOptions.new
      options[:record] = :none

      VCR.use_cassette("none_test", options) do
        expect(VCR.real_http_connections_allowed?).to be_false
      end

      VCR.configuration.allow_http_connections_when_no_cassette = original
    end
  end
end
