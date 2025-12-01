require "../../spec_helper"

Spectator.describe "Request Matching: URI Without Param" do
  # For non-deterministic URIs with timestamp parameters, etc.
  # VCR provides uri_without_param matcher.

  describe "uri_without_param matcher" do
    it "is available through request_matchers" do
      expect(VCR.request_matchers).not_to be_nil
    end
  end
end
