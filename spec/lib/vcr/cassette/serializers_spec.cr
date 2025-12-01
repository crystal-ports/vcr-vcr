require "../../../spec_helper"

Spectator.describe VCR::Cassette::Serializers do
  describe "#[]" do
    it "returns the yaml serializer" do
      serializers = VCR::Cassette::Serializers.new
      expect(serializers[:yaml]).to eq(VCR::Cassette::Serializers::YAML)
    end

    it "returns the json serializer" do
      serializers = VCR::Cassette::Serializers.new
      expect(serializers[:json]).to eq(VCR::Cassette::Serializers::JSON)
    end

    it "returns the compressed serializer" do
      serializers = VCR::Cassette::Serializers.new
      expect(serializers[:compressed]).to eq(VCR::Cassette::Serializers::Compressed)
    end

    it "raises an error for unrecognized serializer name" do
      serializers = VCR::Cassette::Serializers.new
      expect { serializers[:unknown] }.to raise_error(ArgumentError)
    end
  end

  describe "#[]=" do
    it "registers a custom serializer" do
      serializers = VCR::Cassette::Serializers.new
      custom = VCR::Cassette::Serializers::JSON
      serializers[:custom] = custom
      expect(serializers[:custom]).to eq(custom)
    end
  end
end

Spectator.describe VCR::Cassette::Serializers::YAML do
  it "has yml file extension" do
    expect(VCR::Cassette::Serializers::YAML.file_extension).to eq("yml")
  end

  it "can serialize and deserialize a hash" do
    hash = {"a" => "value", "nested" => {"key" => "val"}}
    serialized = VCR::Cassette::Serializers::YAML.serialize(hash)
    expect(serialized).to be_a(String)
    expect(serialized).not_to eq(hash)
  end
end

Spectator.describe VCR::Cassette::Serializers::JSON do
  it "has json file extension" do
    expect(VCR::Cassette::Serializers::JSON.file_extension).to eq("json")
  end

  it "can serialize and deserialize a hash" do
    hash = {"a" => "value", "nested" => {"key" => "val"}}
    serialized = VCR::Cassette::Serializers::JSON.serialize(hash)
    expect(serialized).to be_a(String)
    expect(serialized).to contain("\"a\"")
  end
end

Spectator.describe VCR::Cassette::Serializers::Compressed do
  it "has zz file extension" do
    expect(VCR::Cassette::Serializers::Compressed.file_extension).to eq("zz")
  end
end
