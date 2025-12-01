require "../../spec_helper"

Spectator.describe "Hooks: after_http_request" do
  # The after_http_request hook gets called with each request and response
  # just after a request has completed.
  #
  # The hook receives the request that was made and the response received.

  describe "after_http_request hook" do
    it "is available through configuration" do
      expect(VCR.configuration).not_to be_nil
      expect(VCR.configuration.responds_to?(:after_http_request)).to be_true
    end

    it "can be registered with a block" do
      original_hooks = VCR.configuration.hooks.dup

      begin
        VCR.configuration.after_http_request do |request|
          # Hook that does nothing
        end

        expect(VCR.configuration.has_hooks_for?(:after_http_request)).to be_true
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

    describe "use cases" do
      it "can be used to log responses" do
        responses_logged = [] of Int32
        original_hooks = VCR.configuration.hooks.dup

        begin
          VCR.configuration.after_http_request do |interaction|
            responses_logged << interaction.response.status.code
          end

          # Simulate hook invocation
          request = VCR::Request.new("GET", "http://example.com/test", nil, {} of String => Array(String))
          response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "test")
          interaction = VCR::HTTPInteraction.new(request, response)
          hook_aware = VCR::HTTPInteraction::HookAware.new(interaction)

          VCR.configuration.invoke_hook(:after_http_request, hook_aware)

          expect(responses_logged.size).to eq(1)
          expect(responses_logged.first).to eq(200)
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
end
