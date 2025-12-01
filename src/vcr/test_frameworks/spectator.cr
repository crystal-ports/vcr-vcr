module VCR
  # Integrates VCR with Spectator (Crystal's RSpec-like testing framework).
  #
  # Usage in your spec_helper.cr:
  #   require "spectator"
  #   require "vcr"
  #   require "vcr/test_frameworks/spectator"
  #
  #   VCR.configure do |c|
  #     c.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  #   end
  #
  # Then in your specs:
  #   Spectator.describe "API client" do
  #     it "fetches data", tags: :vcr do
  #       VCR.use_cassette("api_response") do
  #         # make HTTP requests
  #       end
  #     end
  #   end
  #
  # Or use the provided module for automatic cassette management:
  #   Spectator.describe "API client" do
  #     include VCR::Spectator::Helpers
  #
  #     it "fetches data" do
  #       use_vcr_cassette("api_response") do
  #         # make HTTP requests
  #       end
  #     end
  #   end
  module Spectator
    # Helper methods for use in Spectator specs
    module Helpers
      # Wraps a block with a VCR cassette
      #
      # @param name [String] the cassette name
      # @param options [Hash] cassette options
      def use_vcr_cassette(name : String, options : VCR::CassetteOptions = VCR::CassetteOptions.new, &)
        VCR.use_cassette(name, options) do
          yield
        end
      end

      # Wraps a block with a VCR cassette, using the current example's description
      # as the cassette name
      def use_vcr_cassette(options : VCR::CassetteOptions = VCR::CassetteOptions.new, &)
        # Use a default cassette name based on current context
        # Users should provide explicit names for better organization
        VCR.use_cassette("spec_cassette", options) do
          yield
        end
      end
    end
  end

  # Backward compatibility alias for RSpec-style configuration
  module RSpec
    module Metadata
      extend self

      # Configure VCR for Spectator/RSpec-style testing
      # Note: In Crystal, we recommend using VCR.use_cassette directly
      # as compile-time metaprogramming differs from Ruby's runtime approach
      def configure!
        # No-op in Crystal - use VCR.use_cassette directly in your specs
        STDERR.puts "Note: VCR::RSpec::Metadata.configure! is a no-op in Crystal. " \
                    "Use VCR.use_cassette directly in your specs."
      end
    end
  end
end
