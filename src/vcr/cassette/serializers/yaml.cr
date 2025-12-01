require "yaml"

module VCR
  class Cassette
    class Serializers
      # The YAML serializer using Crystal's stdlib YAML.
      #
      # @see JSON
      # @see Compressed
      module YAML
        extend self
        include SerializerInterface

        # The file extension to use for this serializer.
        #
        # @return [String] "yml"
        def file_extension : String
          "yml"
        end

        # Serializes the given hash using YAML.
        #
        # @param [Hash] hash the object to serialize
        # @return [String] the YAML string
        def serialize(hash) : String
          ::YAML.dump(hash)
        end

        # Deserializes the given string using YAML.
        #
        # @param [String] string the YAML string
        # @return [Hash] the deserialized object
        def deserialize(string : String)
          ::YAML.parse(string)
        end
      end
    end
  end
end
