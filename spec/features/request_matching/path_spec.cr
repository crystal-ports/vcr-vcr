require "../../spec_helper"

Spectator.describe "Request Matching: Path" do
  # Use the :path request matcher to match requests on the path portion
  # of the request URI.
  #
  # You can use this (alone, or in combination with :host) as an
  # alternative to :uri so that non-deterministic portions of the URI
  # are not considered as part of the request matching.

  describe ":path matcher" do
    it "is a registered matcher" do
      expect(VCR.request_matchers[:path]).not_to be_nil
    end

    it "can be combined with :host" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:host, :path]
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.match_requests_on).to contain(:path)
    end

    describe "replay interaction that matches the path" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", PATH_MATCHING_CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "returns the about response when requesting /about path" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:path]

        VCR.use_cassette("example", options) do
          # Create a request to /about - should match about interaction
          request = VCR::Request.new("get", "http://different-host.com/about", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("about response")
          end
        end
      end

      it "returns the home response when requesting /home path" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:path]

        VCR.use_cassette("example", options) do
          # Create a request to /home - should match home interaction
          request = VCR::Request.new("get", "http://different-host.com/home", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("home response")
          end
        end
      end

      it "matches regardless of host or query params when only :path is specified" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:path]

        VCR.use_cassette("example", options) do
          # The cassette has requests with specific hosts and query params
          # Since we only match on :path, it should still match
          request = VCR::Request.new("get", "http://any-host.com/about?different=param", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("about response")
          end
        end
      end

      it "does not match when path differs" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:path]

        VCR.use_cassette("example", options) do
          # Request to a different path not in cassette
          request = VCR::Request.new("get", "http://host1.com/unknown-path", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).to be_nil
        end
      end
    end
  end
end
