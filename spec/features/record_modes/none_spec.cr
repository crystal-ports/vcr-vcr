require "../../spec_helper"

Spectator.describe "Record Mode: none" do
  # The :none record mode will:
  # - Replay previously recorded interactions.
  # - Cause an error to be raised for any new requests.
  #
  # This is useful when your code makes potentially dangerous
  # HTTP requests. The :none record mode guarantees that no
  # new HTTP requests will be made.

  describe ":none record mode" do
    it "is a valid record mode" do
      expect(VCR::Cassette::VALID_RECORD_MODES).to contain(:none)
    end

    it "can be set on a cassette" do
      options = VCR::CassetteOptions.new
      options[:record] = :none
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.record_mode).to eq(:none)
    end

    it "indicates the cassette is not recording" do
      options = VCR::CassetteOptions.new
      options[:record] = :none
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.recording?).to be_false
    end

    describe "replaying previously recorded responses" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", SIMPLE_GET_CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "replays responses from the cassette" do
        options = VCR::CassetteOptions.new
        options[:record] = :none

        VCR.use_cassette("example", options) do
          # Create a request that matches the cassette
          request = VCR::Request.new("get", "http://example.com/foo", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("Hello")
          end
        end
      end
    end

    describe "preventing new requests" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", SIMPLE_GET_CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "returns nil for requests not in the cassette" do
        options = VCR::CassetteOptions.new
        options[:record] = :none

        VCR.use_cassette("example", options) do
          # Create a request for a different URI not in the cassette
          request = VCR::Request.new("get", "http://example.com/bar", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          # In :none mode, unmatched requests return nil from http_interactions
          # (the actual HTTP layer would raise an error when trying to make the real request)
          expect(response).to be_nil
        end
      end

      it "does not allow real http connections" do
        options = VCR::CassetteOptions.new
        options[:record] = :none

        VCR.use_cassette("example", options) do
          # With :none mode, real_http_connections_allowed? should be false
          expect(VCR.real_http_connections_allowed?).to be_false
        end
      end
    end
  end
end
