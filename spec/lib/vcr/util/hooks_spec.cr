require "../../../spec_helper"

Spectator.describe VCR::Hooks do
  # Note: The Hooks module is primarily tested through its usage in Configuration
  # Direct testing is limited as the module is designed to be included in classes
end

Spectator.describe VCR::Hooks::FilteredHook do
  it "invokes the hook when no tag is specified" do
    called = false
    hook = ->(interaction : VCR::HTTPInteraction::HookAware, cassette : VCR::Cassette?) { called = true; nil }
    filtered_hook = VCR::Hooks::FilteredHook.new(hook, nil)

    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
    interaction = VCR::HTTPInteraction.new(request, response)
    hook_aware = interaction.hook_aware

    filtered_hook.conditionally_invoke(hook_aware, nil)
    expect(called).to be_true
  end

  it "invokes the hook when cassette has matching tag" do
    called = false
    hook = ->(interaction : VCR::HTTPInteraction::HookAware, cassette : VCR::Cassette?) { called = true; nil }
    filtered_hook = VCR::Hooks::FilteredHook.new(hook, :my_tag)

    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
    interaction = VCR::HTTPInteraction.new(request, response)
    hook_aware = interaction.hook_aware

    with_clean_cassettes do
      cassette = VCR::Cassette.new("test", {:tags => [:my_tag] of Symbol})
      filtered_hook.conditionally_invoke(hook_aware, cassette)
      expect(called).to be_true
    end
  end

  it "does not invoke the hook when cassette lacks the tag" do
    called = false
    hook = ->(interaction : VCR::HTTPInteraction::HookAware, cassette : VCR::Cassette?) { called = true; nil }
    filtered_hook = VCR::Hooks::FilteredHook.new(hook, :my_tag)

    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
    interaction = VCR::HTTPInteraction.new(request, response)
    hook_aware = interaction.hook_aware

    with_clean_cassettes do
      cassette = VCR::Cassette.new("test", {:tags => [:other_tag] of Symbol})
      filtered_hook.conditionally_invoke(hook_aware, cassette)
      expect(called).to be_false
    end
  end
end
