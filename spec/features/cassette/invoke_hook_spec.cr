require "../../spec_helper"

# This spec tests that the Cassette class properly invokes hooks registered
# via VCR.configuration (e.g., filter_sensitive_data, before_record).
#
# Previously, Cassette#invoke_hook only removed ignored interactions but
# did NOT call VCR.configuration.invoke_hook, meaning hooks like
# filter_sensitive_data were never actually invoked during recording.
Spectator.describe "Cassette: invoke_hook integration" do
  around_each do |example|
    FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
    example.run
    FileUtils.rm_rf(SPEC_CASSETTE_DIR)
  end

  describe "before_record hooks via filter_sensitive_data" do
    it "filters sensitive data when cassette is ejected" do
      # This is the actual bug: filter_sensitive_data registers before_record hooks,
      # but Cassette#invoke_hook wasn't calling them.
      original_hooks = VCR.configuration.hooks.dup

      begin
        # Register a filter for sensitive data
        VCR.configuration.filter_sensitive_data("<FILTERED_SECRET>") { "my-secret-api-key" }

        options = VCR::CassetteOptions.new
        options[:record] = :all

        cassette_path : String? = nil

        VCR.use_cassette("filter_test", options) do
          cassette = VCR.current_cassette
          expect(cassette).not_to be_nil

          if c = cassette
            cassette_path = c.file

            # Record an interaction containing the secret
            headers = {"Authorization" => ["Bearer my-secret-api-key"]} of String => Array(String)
            request = VCR::Request.new(
              "get",
              "http://api.example.com/data?key=my-secret-api-key",
              nil,
              headers
            )
            response = VCR::Response.new(
              VCR::ResponseStatus.new(200, "OK"),
              {} of String => Array(String),
              "response containing my-secret-api-key"
            )
            interaction = VCR::HTTPInteraction.new(request, response)
            c.record_http_interaction(interaction)
          end
        end

        # After cassette is ejected, the file should have filtered content
        expect(cassette_path).not_to be_nil
        if path = cassette_path
          expect(File.exists?(path)).to be_true
          cassette_content = File.read(path)

          # The secret should be replaced with the placeholder
          expect(cassette_content).to contain("<FILTERED_SECRET>")
          expect(cassette_content).not_to contain("my-secret-api-key")
        end
      ensure
        VCR.configuration.clear_hooks
        original_hooks.each do |key, hooks|
          hooks.each do |hook|
            VCR.configuration.hooks[key] ||= [] of VCR::Hooks::FilteredHook
            VCR.configuration.hooks[key] << hook
          end
        end
      end
    end

    it "invokes before_record hooks for each interaction" do
      original_hooks = VCR.configuration.hooks.dup
      hook_call_count = 0

      begin
        VCR.configuration.before_record do |interaction|
          hook_call_count += 1
        end

        options = VCR::CassetteOptions.new
        options[:record] = :all

        VCR.use_cassette("hook_count_test", options) do
          cassette = VCR.current_cassette
          if c = cassette
            # Record two interactions
            2.times do |i|
              request = VCR::Request.new("get", "http://example.com/#{i}", nil, {} of String => Array(String))
              response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body #{i}")
              interaction = VCR::HTTPInteraction.new(request, response)
              c.record_http_interaction(interaction)
            end
          end
        end

        # Each interaction should trigger the before_record hook
        expect(hook_call_count).to eq(2)
      ensure
        VCR.configuration.clear_hooks
        original_hooks.each do |key, hooks|
          hooks.each do |hook|
            VCR.configuration.hooks[key] ||= [] of VCR::Hooks::FilteredHook
            VCR.configuration.hooks[key] << hook
          end
        end
      end
    end

    it "allows hooks to mark interactions as ignored" do
      original_hooks = VCR.configuration.hooks.dup

      begin
        # Register a hook that ignores 5xx errors
        VCR.configuration.before_record do |interaction|
          interaction.ignore! if interaction.response.status.code >= 500
        end

        options = VCR::CassetteOptions.new
        options[:record] = :all

        cassette_path : String? = nil

        VCR.use_cassette("ignore_test", options) do
          cassette = VCR.current_cassette
          if c = cassette
            cassette_path = c.file

            # Record a successful interaction
            request1 = VCR::Request.new("get", "http://example.com/ok", nil, {} of String => Array(String))
            response1 = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "success")
            c.record_http_interaction(VCR::HTTPInteraction.new(request1, response1))

            # Record a 500 error (should be ignored)
            request2 = VCR::Request.new("get", "http://example.com/error", nil, {} of String => Array(String))
            response2 = VCR::Response.new(VCR::ResponseStatus.new(500, "Internal Server Error"), {} of String => Array(String), "error")
            c.record_http_interaction(VCR::HTTPInteraction.new(request2, response2))
          end
        end

        # Only the successful interaction should be recorded
        expect(cassette_path).not_to be_nil
        if path = cassette_path
          expect(File.exists?(path)).to be_true
          cassette_content = File.read(path)

          expect(cassette_content).to contain("/ok")
          expect(cassette_content).not_to contain("/error")
        end
      ensure
        VCR.configuration.clear_hooks
        original_hooks.each do |key, hooks|
          hooks.each do |hook|
            VCR.configuration.hooks[key] ||= [] of VCR::Hooks::FilteredHook
            VCR.configuration.hooks[key] << hook
          end
        end
      end
    end
  end

  describe "before_playback hooks" do
    it "invokes before_playback hooks when loading cassette" do
      original_hooks = VCR.configuration.hooks.dup
      hook_call_count = 0

      begin
        # First, record a cassette
        record_options = VCR::CassetteOptions.new
        record_options[:record] = :all

        VCR.use_cassette("playback_hook_test", record_options) do
          cassette = VCR.current_cassette
          if c = cassette
            request = VCR::Request.new("get", "http://example.com/test", nil, {} of String => Array(String))
            response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "test body")
            c.record_http_interaction(VCR::HTTPInteraction.new(request, response))
          end
        end

        # Now register a before_playback hook
        VCR.configuration.before_playback do |interaction|
          hook_call_count += 1
        end

        # Playback the cassette
        playback_options = VCR::CassetteOptions.new
        playback_options[:record] = :none

        VCR.use_cassette("playback_hook_test", playback_options) do
          cassette = VCR.current_cassette
          if c = cassette
            # Force loading of previously recorded interactions by accessing http_interactions
            # This triggers before_playback hooks
            c.http_interactions
          end
        end

        expect(hook_call_count).to eq(1)
      ensure
        VCR.configuration.clear_hooks
        original_hooks.each do |key, hooks|
          hooks.each do |hook|
            VCR.configuration.hooks[key] ||= [] of VCR::Hooks::FilteredHook
            VCR.configuration.hooks[key] << hook
          end
        end
      end
    end
  end
end
