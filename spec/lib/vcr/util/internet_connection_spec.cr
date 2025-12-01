require "../../../spec_helper"

Spectator.describe VCR::InternetConnection do
  describe ".available?" do
    it "returns a boolean" do
      result = VCR::InternetConnection.available?
      expect(result == true || result == false).to be_true
    end

    it "caches the result" do
      result1 = VCR::InternetConnection.available?
      result2 = VCR::InternetConnection.available?
      expect(result1).to eq(result2)
    end
  end
end
