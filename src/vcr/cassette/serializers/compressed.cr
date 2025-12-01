require "compress/zlib"

module VCR
  class Cassette
    class Serializers
      # The compressed serializer. This serializer wraps the YAML serializer
      # to write compressed cassettes to disk.
      #
      # Cassettes containing responses with JSON data often compress at greater
      # than 10:1. The tradeoff is that cassettes will not diff nicely or be
      # easily inspectable or editable.
      #
      # @see YAML
      module Compressed
        extend self
        include SerializerInterface

        # The file extension to use for this serializer.
        #
        # @return [String] "zz"
        def file_extension : String
          "zz"
        end

        # Serializes the given hash using YAML and Zlib.
        #
        # @param [Hash] hash the object to serialize
        # @return [String] the compressed cassette data
        def serialize(hash) : String
          yaml_string = VCR::Cassette::Serializers::YAML.serialize(hash)
          io = IO::Memory.new
          Compress::Zlib::Writer.open(io) do |zlib|
            zlib.print(yaml_string)
          end
          io.to_s
        end

        # Deserializes the given compressed cassette data.
        #
        # @param [String] string the compressed YAML cassette data
        # @return [Hash] the deserialized object
        def deserialize(string : String)
          io = IO::Memory.new(string)
          yaml_string = Compress::Zlib::Reader.open(io) do |zlib|
            zlib.gets_to_end
          end
          VCR::Cassette::Serializers::YAML.deserialize(yaml_string)
        end
      end
    end
  end
end
