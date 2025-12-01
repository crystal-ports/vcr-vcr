require "../../spec_helper"

Spectator.describe "Allow Unused HTTP Interactions" do
  # If set to false, this cassette option will cause VCR to raise an error
  # when a cassette is ejected and there are unused HTTP interactions remaining,
  # unless there is already an exception unwinding the callstack.
  #
  # It verifies that all requests included in the cassette were made, and allows
  # VCR to function a bit like a mock object at the HTTP layer.
  #
  # The option defaults to true (mostly for backwards compatibility).

  describe "allow_unused_http_interactions option" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("example", SIMPLE_GET_CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "allows unused interactions by default" do
      # With default options, unused interactions should be allowed
      VCR.use_cassette("example") do
        # Make no requests - the cassette has one interaction that won't be used
        # This should not raise an error
      end
      # If we got here without exception, the test passes
      expect(true).to be_true
    end

    it "raises an error if option is false and there are unused interactions" do
      options = VCR::CassetteOptions.new
      options[:allow_unused_http_interactions] = false

      expect {
        VCR.use_cassette("example", options) do
          # Make no requests - the cassette has one interaction that won't be used
        end
      }.to raise_error(VCR::Errors::UnusedHTTPInteractionError, /There are unused HTTP interactions left in the cassette/)
    end

    it "does not raise an error if option is false and all interactions are used" do
      options = VCR::CassetteOptions.new
      options[:allow_unused_http_interactions] = false

      VCR.use_cassette("example", options) do
        # Use the interaction by making a matching request
        request = VCR::Request.new("get", "http://example.com/foo", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(request)
        expect(response).not_to be_nil
      end
      # If we got here without exception, the test passes
      expect(true).to be_true
    end

    it "does not silence other errors raised in use_cassette block" do
      options = VCR::CassetteOptions.new
      options[:allow_unused_http_interactions] = false

      error_raised = false
      begin
        VCR.use_cassette("example", options) do
          raise "boom"
        end
      rescue ex
        error_raised = true
        # The error should be our "boom" error, not an UnusedHTTPInteractionError
        expect(ex.message).to eq("boom")
        expect(ex).not_to be_a(VCR::Errors::UnusedHTTPInteractionError)
      end
      expect(error_raised).to be_true
    end
  end
end
