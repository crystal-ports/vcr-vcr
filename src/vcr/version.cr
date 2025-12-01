module VCR
  class Version
    getter value : String

    def initialize(@value : String)
    end

    forward_missing_to @value

    def parts
      @value.split(".").map(&.to_i)
    end

    def major
      parts[0]
    end

    def minor
      parts[1]
    end

    def patch
      parts[2]
    end

    def to_s(io : IO) : Nil
      io << @value
    end
  end

  extend self

  # @return [String] the current VCR version.
  # @note This string also has singleton methods:
  #
  #   * `major` [Integer] The major version.
  #   * `minor` [Integer] The minor version.
  #   * `patch` [Integer] The patch version.
  #   * `parts` [Array<Integer>] List of the version parts.
  def version : Version
    @@version ||= Version.new("6.3.1")
  end
end
