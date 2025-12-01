module VCR
  class Cassette
    # @private
    # Renderer for ECR cassette templates.
    # Since Crystal's ECR is compile-time, we use simple string substitution
    # for dynamic templates.
    class ECRRenderer
      @raw_template : String?
      @ecr : Hash(String, String) | Bool | Nil
      @cassette_name : String

      def initialize(@raw_template : String?, @ecr : Hash(String, String) | Bool | Nil, @cassette_name : String = "unknown")
      end

      def render : String?
        template = @raw_template
        return template if template.nil? || !use_ecr?

        result = template

        if variables = ecr_variables
          # Simple string substitution for <%= variable %> patterns
          variables.each do |key, value|
            result = result.gsub(/<%= *#{Regex.escape(key)} *%>/, value)
          end
        end

        # Check for any remaining ECR tags that weren't substituted
        if result =~ /<%=\s*(\w+)\s*%>/
          variable_name = $1
          example_hash = (ecr_variables || {} of String => String).merge({variable_name => "some value"})
          raise Errors::MissingECRVariableError.new(
            "The ECR in the #{@cassette_name} cassette file references undefined variable #{variable_name}. " +
            "Pass it to the cassette using :ecr => #{example_hash.inspect}."
          )
        end

        result
      end

      private def use_ecr? : Bool
        !!@ecr
      end

      private def ecr_variables : Hash(String, String)?
        case @ecr
        when Hash(String, String)
          ecr_hash = @ecr.as(Hash(String, String))
          ecr_hash.empty? ? nil : ecr_hash
        else
          nil
        end
      end
    end
  end
end
