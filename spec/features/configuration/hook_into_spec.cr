require "../../spec_helper"

Spectator.describe "Configuration: Hook Into" do
  # Configure VCR to hook into HTTP libraries.
  # This allows VCR to intercept HTTP requests made by various libraries.

  describe "hook_into" do
    it "is available through configuration" do
      expect(VCR.configuration).not_to be_nil
    end

    it "can configure library hooks" do
      # Library hooks are configured to intercept HTTP requests
      expect(VCR.library_hooks).not_to be_nil
    end
  end

  describe "LibraryHooks" do
    it "provides access to available hooks" do
      expect(VCR.library_hooks).not_to be_nil
    end

    it "is a LibraryHooks instance" do
      expect(VCR.library_hooks).to be_a(VCR::LibraryHooks)
    end

    it "can track exclusive hooks" do
      hooks = VCR.library_hooks
      expect(hooks.exclusive_hook).to be_nil
    end

    it "disabled? returns false when no exclusive hook" do
      hooks = VCR.library_hooks
      expect(hooks.disabled?(:webmock)).to be_false
    end
  end

  describe "hook behavior" do
    it "hooks can be enabled globally" do
      # Library hooks intercept HTTP requests globally when enabled
      expect(VCR.library_hooks).not_to be_nil
    end

    it "exclusively_enabled sets and clears exclusive_hook" do
      hooks = VCR.library_hooks
      result = nil

      hooks.exclusively_enabled(:test_hook) do
        result = hooks.exclusive_hook
      end

      expect(result).to eq(:test_hook)
      expect(hooks.exclusive_hook).to be_nil
    end

    it "disabled? returns true for other hooks when exclusive is set" do
      hooks = VCR.library_hooks

      hooks.exclusively_enabled(:webmock) do
        expect(hooks.disabled?(:faraday)).to be_true
        expect(hooks.disabled?(:webmock)).to be_false
      end
    end
  end
end
