require "../../spec_helper"

Spectator.describe "Hooks: around_http_request" do
  # The around_http_request hook wraps each HTTP request.
  # It can be used to control the request lifecycle.
  #
  # Note: This hook requires fiber support and is more complex to use
  # than before_http_request and after_http_request.

  describe "around_http_request hook" do
    it "is available through configuration" do
      expect(VCR.configuration).not_to be_nil
      expect(VCR.configuration.responds_to?(:around_http_request)).to be_true
    end

    it "requires fibers to be available" do
      # Crystal has native fiber support
      expect(VCR.fibers_available?).to be_true
    end

    describe "relationship to other hooks" do
      it "can be used instead of separate before/after hooks" do
        # The around_http_request hook is essentially a combination of
        # before_http_request and after_http_request that yields control
        # to the actual HTTP request in between.
        #
        # This is useful for wrapping requests in transactions,
        # switching cassettes dynamically, etc.

        # Verify both hooks can be registered
        original_hooks = VCR.configuration.hooks.dup

        begin
          VCR.configuration.before_http_request do |request|
            # before logic
          end

          VCR.configuration.after_http_request do |request|
            # after logic
          end

          expect(VCR.configuration.has_hooks_for?(:before_http_request)).to be_true
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
    end
  end
end
