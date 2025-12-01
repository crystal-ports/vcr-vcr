require "../../spec_helper"

Spectator.describe "VCR.version" do
  it "returns a version object" do
    expect(VCR.version.value).to match(/\A\d+\.\d+\.\d+(\.\w+)?\z/)
  end

  it "has major, minor, and patch methods" do
    expect(VCR.version.major).to be > 0
    expect(VCR.version.minor).to be >= 0
    expect(VCR.version.patch).to be >= 0
  end
end
