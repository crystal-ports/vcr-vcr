module VCR
  class Cassette
    # @private
    # Migrator for converting VCR 1.x cassettes to VCR 2.x format.
    # Note: This functionality is limited in Crystal as VCR 1.x cassettes
    # were Ruby-specific. New Crystal projects should start fresh.
    class Migrator
      @dir : String
      @out : IO

      def initialize(@dir : String, @out : IO = STDOUT)
      end

      def migrate!
        @out.puts "Migrating VCR cassettes in #{@dir}..."
        Dir.glob("#{@dir}/**/*.yml").each do |cassette|
          migrate_cassette(cassette)
        end
      end

      private def migrate_cassette(cassette : String)
        @out.puts "  - Skipping #{relative_cassette_name(cassette)} - manual migration may be required"
      end

      private def relative_cassette_name(cassette : String) : String
        cassette.sub(@dir, "").lstrip('/')
      end
    end
  end
end
