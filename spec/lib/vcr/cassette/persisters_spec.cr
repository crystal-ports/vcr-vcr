require "../../../spec_helper"

Spectator.describe VCR::Cassette::Persisters do
  describe "#[]" do
    it "returns the file_system persister" do
      persisters = VCR::Cassette::Persisters.new
      expect(persisters[:file_system]).to eq(VCR::Cassette::Persisters::FileSystem)
    end

    it "raises an error for unrecognized persister name" do
      persisters = VCR::Cassette::Persisters.new
      expect { persisters[:unknown] }.to raise_error(ArgumentError)
    end
  end

  describe "#[]=" do
    it "registers a custom persister" do
      persisters = VCR::Cassette::Persisters.new
      custom = VCR::Cassette::Persisters::FileSystem
      persisters[:custom] = custom
      expect(persisters[:custom]).to eq(custom)
    end
  end
end
