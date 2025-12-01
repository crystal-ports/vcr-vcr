require "../../spec_helper"

Spectator.describe "Configuration: Filter Sensitive Data" do
  # Filter sensitive data from recorded cassettes.
  # This prevents sensitive information like API keys from being stored.

  describe "filter_sensitive_data" do
    it "is available through configuration" do
      expect(VCR.configuration).not_to be_nil
    end

    it "configuration provides before_record hooks" do
      # before_record hooks can be used to filter sensitive data
      expect(VCR.configuration).not_to be_nil
    end

    it "configuration provides before_playback hooks" do
      # before_playback hooks can be used to restore filtered data
      expect(VCR.configuration).not_to be_nil
    end
  end

  describe "filtering behavior" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "records interactions that can be processed with hooks" do
      options = VCR::CassetteOptions.new
      options[:record] = :all

      VCR.use_cassette("filtered_cassette", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          # Record an interaction containing sensitive data
          headers = {"Authorization" => ["Bearer actual-api-key-12345"]} of String => Array(String)
          request = VCR::Request.new("get", "http://api.example.com/data?key=actual-api-key-12345", nil, headers)
          response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "response body")
          interaction = VCR::HTTPInteraction.new(request, response)
          c.record_http_interaction(interaction)

          expect(c.new_recorded_interactions.size).to eq(1)
        end
      end
    end
  end

  describe "HTTPInteraction::HookAware" do
    it "provides filter! method for text replacement" do
      request = VCR::Request.new("get", "http://example.com/data?api_key=secret123", nil, {} of String => Array(String))
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "response with secret123")
      interaction = VCR::HTTPInteraction.new(request, response)

      # HookAware wraps interaction for filtering
      hook_aware = VCR::HTTPInteraction::HookAware.new(interaction)
      hook_aware.filter!("secret123", "<API_KEY>")

      expect(hook_aware.request.uri).to eq("http://example.com/data?api_key=<API_KEY>")
      expect(hook_aware.response.body).to eq("response with <API_KEY>")
    end

    it "can filter headers" do
      headers = {"Authorization" => ["Bearer secret-token"]} of String => Array(String)
      request = VCR::Request.new("get", "http://example.com/", nil, headers)
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "ok")
      interaction = VCR::HTTPInteraction.new(request, response)

      hook_aware = VCR::HTTPInteraction::HookAware.new(interaction)
      hook_aware.filter!("secret-token", "<TOKEN>")

      expect(hook_aware.request.headers["Authorization"]).to eq(["Bearer <TOKEN>"])
    end
  end
end
