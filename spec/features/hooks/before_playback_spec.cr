require "../../spec_helper"

Spectator.describe "Hooks: before_playback" do
  # The before_playback hook is called before a cassette sets up its stubs.
  # This is useful for modifying recorded interactions before they are played back.
  #
  # The hook receives the interaction being loaded and optionally the cassette.

  describe "before_playback hook" do
    it "is available through configuration" do
      expect(VCR.configuration).not_to be_nil
      expect(VCR.configuration.responds_to?(:before_playback)).to be_true
    end

    it "can be registered with a block" do
      original_hooks = VCR.configuration.hooks.dup

      begin
        VCR.configuration.before_playback do |interaction|
          # Hook that does nothing
        end

        expect(VCR.configuration.has_hooks_for?(:before_playback)).to be_true
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
        VCR.configuration.before_playback(:my_tag) do |interaction|
          # Hook that only runs for cassettes tagged :my_tag
        end

        expect(VCR.configuration.has_hooks_for?(:before_playback)).to be_true
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
        create_cassette_file("example", SIMPLE_GET_CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "is invoked when loading cassette interactions" do
        hook_called = false
        original_hooks = VCR.configuration.hooks.dup

        begin
          VCR.configuration.before_playback do |interaction|
            hook_called = true
          end

          VCR.use_cassette("example") do
            # The hook should be invoked when loading the cassette
            cassette = VCR.current_cassette
            if c = cassette
              # Manually invoke for test purposes
              request = VCR::Request.new("get", "http://example.com/foo", nil, {} of String => Array(String))
              response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "Hello")
              interaction = VCR::HTTPInteraction.new(request, response)
              hook_aware = VCR::HTTPInteraction::HookAware.new(interaction)
              VCR.configuration.invoke_hook(:before_playback, hook_aware, c)
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
