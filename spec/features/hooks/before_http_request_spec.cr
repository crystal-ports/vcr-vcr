require "../../spec_helper"

Spectator.describe "Hooks: before_http_request" do
  # The before_http_request hook gets called with each request just before it proceeds.
  # This allows you to intercept requests and take action before they are made.
  #
  # The hook receives the request that is about to be made.

  describe "before_http_request hook" do
    it "is available through configuration" do
      expect(VCR.configuration).not_to be_nil
      expect(VCR.configuration.responds_to?(:before_http_request)).to be_true
    end

    it "can be registered with a block" do
      original_hooks = VCR.configuration.hooks.dup

      begin
        VCR.configuration.before_http_request do |request|
          # Hook that does nothing
        end

        expect(VCR.configuration.has_hooks_for?(:before_http_request)).to be_true
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

    it "can be registered with a tag filter" do
      original_hooks = VCR.configuration.hooks.dup

      begin
        VCR.configuration.before_http_request(:real_tag) do |request|
          # Hook that only runs for certain requests
        end

        expect(VCR.configuration.has_hooks_for?(:before_http_request)).to be_true
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
      it "can be used to log requests" do
        requests_logged = [] of String
        original_hooks = VCR.configuration.hooks.dup

        begin
          VCR.configuration.before_http_request do |request|
            requests_logged << "#{request.request.method} #{request.request.uri}"
          end

          # Simulate hook invocation
          request = VCR::Request.new("GET", "http://example.com/test", nil, {} of String => Array(String))
          response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "test")
          interaction = VCR::HTTPInteraction.new(request, response)
          hook_aware = VCR::HTTPInteraction::HookAware.new(interaction)

          VCR.configuration.invoke_hook(:before_http_request, hook_aware)

          expect(requests_logged.size).to eq(1)
          expect(requests_logged.first).to eq("GET http://example.com/test")
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
