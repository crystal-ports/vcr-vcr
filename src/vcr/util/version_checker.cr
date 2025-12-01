module VCR
  # @private
  class VersionChecker
    @library_name : String
    @library_version : String
    @min_version : String
    @major : Int32
    @minor : Int32
    @patch : Int32
    @min_major : Int32
    @min_minor : Int32
    @min_patch : Int32

    def initialize(@library_name : String, @library_version : String, @min_version : String)
      @major, @minor, @patch = parse_version(@library_version)
      @min_major, @min_minor, @min_patch = parse_version(@min_version)
    end

    def check_version!
      raise_too_low_error if too_low?
    end

    private def too_low? : Bool
      compare_version == :too_low
    end

    private def raise_too_low_error
      raise Errors::LibraryVersionTooLowError.new(
        "You are using #{@library_name} #{@library_version}. " +
        "VCR requires version #{version_requirement}."
      )
    end

    private def compare_version : Symbol?
      case
      when @major < @min_major then :too_low
      when @major > @min_major then :ok
      when @minor < @min_minor then :too_low
      when @minor > @min_minor then :ok
      when @patch < @min_patch then :too_low
      else                          nil
      end
    end

    private def version_requirement : String
      ">= #{@min_version}"
    end

    private def parse_version(version : String) : Tuple(Int32, Int32, Int32)
      parts = version.split('.').map(&.to_i)
      {parts[0]? || 0, parts[1]? || 0, parts[2]? || 0}
    end
  end
end
