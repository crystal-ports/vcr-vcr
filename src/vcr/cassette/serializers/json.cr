require "json"

module VCR
  class Cassette
    class Serializers
      # The JSON serializer.
      #
      # @see YAML
      # @see Compressed
      module JSON
        extend self
        include SerializerInterface

        # The file extension to use for this serializer.
        #
        # @return [String] "json"
        def file_extension : String
          "json"
        end

        # Serializes the given hash using `JSON`.
        #
        # @param [Hash] hash the object to serialize
        # @return [String] the JSON string
        def serialize(hash) : String
          hash.to_pretty_json
        end

        # Deserializes the given string using `JSON`.
        #
        # @param [String] string the JSON string
        # @return [Hash] the deserialized object
        def deserialize(string : String)
          ::JSON.parse(string)
        end
      end
    end
  end
end
