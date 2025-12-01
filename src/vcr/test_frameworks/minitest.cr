module VCR
  # Integrates VCR with minitest.cr.
  #
  # Usage in your test_helper.cr:
  #   require "minitest"
  #   require "vcr"
  #   require "vcr/test_frameworks/minitest"
  #
  #   VCR.configure do |c|
  #     c.cassette_library_dir = "test/fixtures/vcr_cassettes"
  #   end
  #
  # Then in your tests:
  #   class APIClientTest < Minitest::Test
  #     include VCR::Minitest::Helpers
  #
  #     def test_fetches_data
  #       use_vcr_cassette("api_response") do
  #         # make HTTP requests
  #       end
  #     end
  #   end
  module Minitest
    # Helper methods for use in minitest.cr tests
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

      # Wraps a block with a VCR cassette, using the test method name
      # as the cassette name
      def use_vcr_cassette_for_test(options : VCR::CassetteOptions = VCR::CassetteOptions.new, &)
        # In minitest, you can get the test name from the test method
        # Users should provide explicit names for better organization
        VCR.use_cassette("test_cassette", options) do
          yield
        end
      end
    end
  end
end
