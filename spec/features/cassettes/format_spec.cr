require "../../spec_helper"

Spectator.describe "Cassette Format" do
  # VCR supports multiple serialization formats for cassettes.
  # The default is YAML, but JSON is also available.
  #
  # Use the :serialize_with option to specify the format.

  describe "serialize_with option" do
    it "defaults to :yaml" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette).not_to be_nil
    end

    it "can be set to :json" do
      options = VCR::CassetteOptions.new
      options[:serialize_with] = :json
      cassette = VCR::Cassette.new("test", options)
      expect(cassette).not_to be_nil
    end
  end

  describe VCR::Cassette::Serializers do
    it "provides a YAML serializer" do
      serializers = VCR::Cassette::Serializers.new
      yaml_serializer = serializers[:yaml]
      expect(yaml_serializer.file_extension).to eq("yml")
    end

    it "provides a JSON serializer" do
      serializers = VCR::Cassette::Serializers.new
      json_serializer = serializers[:json]
      expect(json_serializer.file_extension).to eq("json")
    end
  end

  describe "YAML serialization" do
    it "serializes a hash to YAML format" do
      serializers = VCR::Cassette::Serializers.new
      yaml_serializer = serializers[:yaml]

      data = {
        "http_interactions" => [
          {
            "request"  => {"method" => "GET", "uri" => "http://example.com/"},
            "response" => {"status" => {"code" => 200, "message" => "OK"}, "body" => "Hello"},
          },
        ],
        "recorded_with" => "VCR",
      }

      serialized = yaml_serializer.serialize(data)
      expect(serialized).to contain("http_interactions")
      expect(serialized).to contain("GET")
      expect(serialized).to contain("http://example.com/")
    end

    it "deserializes YAML content back to a hash" do
      serializers = VCR::Cassette::Serializers.new
      yaml_serializer = serializers[:yaml]

      yaml_content = <<-YAML
      ---
      http_interactions:
      - request:
          method: GET
          uri: http://example.com/
        response:
          status:
            code: 200
            message: OK
          body: Hello
      recorded_with: VCR
      YAML

      result = yaml_serializer.deserialize(yaml_content)
      expect(result).to be_a(YAML::Any | Hash(String, YAML::Any))
    end
  end

  describe "JSON serialization" do
    it "serializes a hash to JSON format" do
      serializers = VCR::Cassette::Serializers.new
      json_serializer = serializers[:json]

      data = {
        "http_interactions" => [
          {
            "request"  => {"method" => "GET", "uri" => "http://example.com/"},
            "response" => {"status" => {"code" => 200, "message" => "OK"}, "body" => "Hello"},
          },
        ],
        "recorded_with" => "VCR",
      }

      serialized = json_serializer.serialize(data)
      expect(serialized).to contain("http_interactions")
      expect(serialized).to contain("GET")
      expect(serialized).to contain("http://example.com/")
    end

    it "deserializes JSON content back to a hash" do
      serializers = VCR::Cassette::Serializers.new
      json_serializer = serializers[:json]

      json_content = <<-JSON
      {
        "http_interactions": [
          {
            "request": {"method": "GET", "uri": "http://example.com/"},
            "response": {"status": {"code": 200, "message": "OK"}, "body": "Hello"}
          }
        ],
        "recorded_with": "VCR"
      }
      JSON

      result = json_serializer.deserialize(json_content)
      expect(result).to be_a(JSON::Any | Hash(String, JSON::Any))
    end
  end

  describe "file extension" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "uses .yml extension for YAML cassettes" do
      options = VCR::CassetteOptions.new
      options[:serialize_with] = :yaml
      options[:record] = :all

      VCR.use_cassette("yaml_test", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.file).to contain(".yml")
        end
      end
    end

    it "uses .json extension for JSON cassettes" do
      options = VCR::CassetteOptions.new
      options[:serialize_with] = :json
      options[:record] = :all

      VCR.use_cassette("json_test", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.file).to contain(".json")
        end
      end
    end
  end
end
