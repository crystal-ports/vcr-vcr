module VCR
  class Cassette
    # Keeps track of the cassette persisters in a hash-like object.
    class Persisters
      @persisters : Hash(Symbol, FileSystem.class)

      # @private
      def initialize
        @persisters = {} of Symbol => FileSystem.class
        # Register default persister
        @persisters[:file_system] = FileSystem
      end

      # Gets the named persister.
      #
      # @param name [Symbol] the name of the persister
      # @return the named persister
      # @raise [ArgumentError] if there is not a persister for the given name
      def [](name : Symbol) : FileSystem.class
        @persisters.fetch(name) do
          raise ArgumentError.new("The requested VCR cassette persister " +
                                  "(#{name.inspect}) is not registered.")
        end
      end

      # Registers a persister.
      #
      # @param name [Symbol] the name of the persister
      # @param value [#[], #[]=] the persister object. It must implement `[]` and `[]=`.
      def []=(name : Symbol, value : FileSystem.class)
        if @persisters.has_key?(name)
          STDERR.puts "WARNING: There is already a VCR cassette persister " +
                      "registered for #{name.inspect}. Overriding it."
        end
        @persisters[name] = value
      end
    end
  end
end

require "./persisters/file_system" # Converted from: autoload :FileSystem, "vcr/cassette/persisters/file_system"
