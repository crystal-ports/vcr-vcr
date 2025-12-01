require "../../spec_helper"

Spectator.describe "Record On Error" do
  # The :record_on_error flag prevents a cassette from being recorded
  # when the code that uses the cassette raises an error.

  describe "record_on_error option" do
    it "defaults to the value from configuration" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      # Default depends on VCR.configuration.default_cassette_options
      expect(cassette.record_on_error?).to be_a(Bool)
    end

    it "can be set to true" do
      options = VCR::CassetteOptions.new
      options[:record_on_error] = true
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.record_on_error?).to be_true
    end

    it "can be set to false explicitly" do
      options = VCR::CassetteOptions.new
      options[:record_on_error] = false
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.record_on_error?).to be_false
    end
  end

  describe "run_failed!" do
    it "marks the cassette as failed" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette.run_failed?).to be_false
      cassette.run_failed!
      expect(cassette.run_failed?).to be_true
    end
  end
end
