require "../../spec_helper"

Spectator.describe "Hooks: before_record" do
  # The before_record hook is called before a cassette is written to disk.
  # This is useful for filtering sensitive data or modifying interactions
  # before they are recorded.
  #
  # The hook receives the interaction being recorded and optionally the cassette.

  describe "before_record hook" do
    it "is available through configuration" do
      expect(VCR.configuration).not_to be_nil
      expect(VCR.configuration.responds_to?(:before_record)).to be_true
    end

    it "can be registered with a block" do
      original_hooks = VCR.configuration.hooks.dup

      begin
        VCR.configuration.before_record do |interaction|
          # Hook that does nothing
        end

        expect(VCR.configuration.has_hooks_for?(:before_record)).to be_true
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
        VCR.configuration.before_record(:my_tag) do |interaction|
          # Hook that only runs for cassettes tagged :my_tag
        end

        expect(VCR.configuration.has_hooks_for?(:before_record)).to be_true
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

    describe "invoking the hook" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "allows access to the interaction" do
        hook_called = false
        original_hooks = VCR.configuration.hooks.dup

        begin
          VCR.configuration.before_record do |interaction|
            hook_called = true
            # We can access the interaction's request and response
            expect(interaction.request).not_to be_nil
            expect(interaction.response).not_to be_nil
          end

          options = VCR::CassetteOptions.new
          options[:record] = :all

          VCR.use_cassette("test_hook", options) do
            # Record an interaction
            cassette = VCR.current_cassette
            if c = cassette
              request = VCR::Request.new("get", "http://example.com/test", nil, {} of String => Array(String))
              response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "test body")
              interaction = VCR::HTTPInteraction.new(request, response)

              # Create a hook-aware version
              hook_aware = VCR::HTTPInteraction::HookAware.new(interaction)

              # Invoke the hook
              VCR.configuration.invoke_hook(:before_record, hook_aware, c)
            end
          end

          expect(hook_called).to be_true
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
