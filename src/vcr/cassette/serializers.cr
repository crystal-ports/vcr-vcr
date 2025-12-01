module VCR
  class Cassette
    # Base module for serializers
    module SerializerInterface
      abstract def file_extension : String
      abstract def serialize(hash) : String
      abstract def deserialize(string : String)
    end

    # Keeps track of the cassette serializers in a hash-like object.
    class Serializers
      # @private
      def initialize
        @serializers = {} of Symbol => SerializerInterface
      end

      # Gets the named serializer.
      #
      # @param name [Symbol] the name of the serializer
      # @return the named serializer
      # @raise [ArgumentError] if there is not a serializer for the given name
      def [](name : Symbol) : SerializerInterface
        return @serializers[name] if @serializers.has_key?(name)

        @serializers[name] = case name
                             when :yaml, :syck, :psych
                               YAML
                             when :json
                               JSON
                             when :compressed
                               Compressed
                             else
                               raise ArgumentError.new("The requested VCR cassette serializer (#{name.inspect}) is not registered.")
                             end
      end

      # Registers a serializer.
      #
      # @param name [Symbol] the name of the serializer
      # @param value [#file_extension, #serialize, #deserialize] the serializer object. It must implement
      #  `file_extension()`, `serialize(Hash)` and `deserialize(String)`.
      def []=(name : Symbol, value : SerializerInterface)
        if @serializers.has_key?(name)
          puts "WARNING: There is already a VCR cassette serializer registered for #{name.inspect}. Overriding it."
        end
        @serializers[name] = value
      end
    end

    # @private
    module EncodingErrorHandling
      def handle_encoding_errors(&)
        yield
      end
    end

    # @private
    module SyntaxErrorHandling
      def handle_syntax_errors(&)
        yield
      end
    end
  end
end

require "./serializers/yaml"
require "./serializers/json"
require "./serializers/compressed"
