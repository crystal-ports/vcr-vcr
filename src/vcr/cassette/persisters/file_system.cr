module VCR
  class Cassette
    class Persisters
      # The only built-in cassette persister. Persists cassettes to the file system.
      module FileSystem
        extend self

        @@storage_location : String?

        def storage_location : String?
          @@storage_location
        end

        # @private
        def storage_location=(dir : String?)
          if dir
            Dir.mkdir_p(dir)
            @@storage_location = absolute_path_for(dir)
          else
            @@storage_location = nil
          end
        end

        # Gets the cassette for the given storage key (file name).
        #
        # @param [String] file_name the file name
        # @return [String] the cassette content
        def [](file_name : String) : String?
          path = absolute_path_to_file(file_name)
          return nil if path.nil?
          return nil unless File.exists?(path)
          File.read(path)
        end

        # Sets the cassette for the given storage key (file name).
        #
        # @param [String] file_name the file name
        # @param [String] content the content to store
        def []=(file_name : String, content : String)
          path = absolute_path_to_file(file_name)
          return if path.nil?
          directory = File.dirname(path)
          Dir.mkdir_p(directory) unless File.exists?(directory)
          File.write(path, content)
        end

        # @private
        def absolute_path_to_file(file_name : String) : String?
          loc = storage_location
          return nil unless loc
          File.join(loc, sanitized_file_name_from(file_name))
        end

        private def absolute_path_for(path : String) : String
          Dir.cd(path) { Dir.current }
        end

        private def sanitized_file_name_from(file_name : String) : String
          parts = file_name.to_s.split(".")
          file_extension = ""

          if parts.size > 1 && !parts.last.includes?(File::SEPARATOR)
            file_extension = "." + parts.pop
          end
          result = parts.join(".").gsub(/[^\w\/-]+/, "_") + file_extension
          result = result.downcase if downcase_cassette_names?
          result
        end

        private def downcase_cassette_names? : Bool
          opts = VCR.configuration.default_cassette_options
          if persister_opts = opts[:persister_options]?
            if persister_opts.is_a?(Hash)
              !!persister_opts[:downcase_cassette_names]?
            else
              false
            end
          else
            false
          end
        end
      end
    end
  end
end
