require "../../spec_helper"

Spectator.describe "Update Content-Length Header" do
  # VCR can automatically update the Content-Length header
  # to match the actual response body length.

  describe "update_content_length_header option" do
    it "can be enabled via cassette options" do
      options = VCR::CassetteOptions.new
      options[:update_content_length_header] = true
      cassette = VCR::Cassette.new("test", options)
      expect(cassette).not_to be_nil
    end
  end
end
