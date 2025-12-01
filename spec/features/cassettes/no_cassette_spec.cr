require "../../spec_helper"

Spectator.describe "No Cassette" do
  # VCR behavior when no cassette is in use.

  describe "current_cassette" do
    it "returns nil when no cassette is inserted" do
      expect(VCR.current_cassette).to be_nil
    end

    it "returns a cassette when one is inserted" do
      VCR.insert_cassette("test", VCR::CassetteOptions.new)
      expect(VCR.current_cassette).not_to be_nil
      VCR.eject_cassette
      expect(VCR.current_cassette).to be_nil
    end
  end

  describe "real_http_connections_allowed?" do
    it "depends on allow_http_connections_when_no_cassette configuration" do
      # When no cassette is in use, behavior depends on configuration
      expect(VCR.real_http_connections_allowed?).to be_a(Bool)
    end

    it "is controlled by configuration when no cassette" do
      original = VCR.configuration.allow_http_connections_when_no_cassette?

      # Test with false
      VCR.configuration.allow_http_connections_when_no_cassette = false
      expect(VCR.real_http_connections_allowed?).to be_false

      # Test with true
      VCR.configuration.allow_http_connections_when_no_cassette = true
      expect(VCR.real_http_connections_allowed?).to be_true

      # Restore original
      VCR.configuration.allow_http_connections_when_no_cassette = original
    end
  end

  describe "http_interactions" do
    it "returns a null list when no cassette is inserted" do
      expect(VCR.current_cassette).to be_nil
      # With no cassette, http_interactions should return nil or handle gracefully
      interactions = VCR.http_interactions
      expect(interactions).to be_a(VCR::Cassette::HTTPInteractionList::NullList)
    end

    it "response_for returns nil from null list" do
      expect(VCR.current_cassette).to be_nil
      request = VCR::Request.new("get", "http://example.com/", nil, {} of String => Array(String))
      response = VCR.http_interactions.response_for(request)
      expect(response).to be_nil
    end
  end

  describe "use_cassette vs no cassette" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "cassette is only active during use_cassette block" do
      # Before block
      expect(VCR.current_cassette).to be_nil

      options = VCR::CassetteOptions.new
      options[:record] = :all

      VCR.use_cassette("during_block", options) do
        # During block
        expect(VCR.current_cassette).not_to be_nil
        expect(VCR.current_cassette.try(&.name)).to eq("during_block")
      end

      # After block
      expect(VCR.current_cassette).to be_nil
    end

    it "cassette is ejected even if block raises" do
      expect(VCR.current_cassette).to be_nil

      options = VCR::CassetteOptions.new
      options[:record] = :all
      options[:allow_unused_http_interactions] = true

      begin
        VCR.use_cassette("with_error", options) do
          expect(VCR.current_cassette).not_to be_nil
          raise "test error"
        end
      rescue
        # Expected
      end

      # Cassette should be ejected after error
      expect(VCR.current_cassette).to be_nil
    end
  end

  describe "cassette operations without cassette" do
    it "insert_cassette and eject_cassette work correctly" do
      expect(VCR.current_cassette).to be_nil

      VCR.insert_cassette("manual_test", VCR::CassetteOptions.new)
      expect(VCR.current_cassette).not_to be_nil
      expect(VCR.current_cassette.try(&.name)).to eq("manual_test")

      VCR.eject_cassette
      expect(VCR.current_cassette).to be_nil
    end
  end
end
