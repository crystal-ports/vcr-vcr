require "../../../spec_helper"

Spectator.describe VCR::Hooks do
  # Note: The Hooks module is primarily tested through its usage in Configuration
  # Direct testing is limited as the module is designed to be included in classes
end

Spectator.describe VCR::Hooks::FilteredHook do
  it "invokes the hook" do
    called = false
    hook = ->(interaction : VCR::HTTPInteraction::HookAware, cassette : VCR::Cassette?) { called = true; nil }
    filters = [] of Proc(VCR::HTTPInteraction::HookAware, Bool)
    filtered_hook = VCR::Hooks::FilteredHook.new(hook, filters)

    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
    interaction = VCR::HTTPInteraction.new(request, response)
    hook_aware = interaction.hook_aware

    filtered_hook.conditionally_invoke(hook_aware, nil)
    expect(called).to be_true
  end
end
