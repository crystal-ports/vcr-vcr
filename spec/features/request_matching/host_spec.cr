require "../../spec_helper"

Spectator.describe "Request Matching: Host" do
  # Use the :host request matcher to match requests on the request host.
  #
  # You can use this (alone, or in combination with :path) as an
  # alternative to :uri so that non-deterministic portions of the URI
  # are not considered as part of the request matching.

  describe ":host matcher" do
    it "is a registered matcher" do
      expect(VCR.request_matchers[:host]).not_to be_nil
    end

    it "can be used as an alternative to :uri" do
      options = VCR::CassetteOptions.new
      options[:match_requests_on] = [:host, :path]
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.match_requests_on).to eq([:host, :path])
    end

    describe "replay interaction that matches the host" do
      around_each do |example|
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
        FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
        create_cassette_file("example", HOST_MATCHING_CASSETTE_YAML)
        example.run
        FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      end

      it "returns the host1 response when requesting from host1" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:host]

        VCR.use_cassette("example", options) do
          # Create a request to host1 - should match host1 interaction
          request = VCR::Request.new("get", "http://host1.com/different/path", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("host1 response")
          end
        end
      end

      it "returns the host2 response when requesting from host2" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:host]

        VCR.use_cassette("example", options) do
          # Create a request to host2 - should match host2 interaction
          request = VCR::Request.new("get", "http://host2.com/any/path", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("host2 response")
          end
        end
      end

      it "matches regardless of HTTP method or path when only :host is specified" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:host]

        VCR.use_cassette("example", options) do
          # The cassette has POST requests with specific paths, but we're using GET with different paths
          # Since we only match on :host, it should still match
          request = VCR::Request.new("get", "http://host1.com/completely/different", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).not_to be_nil
          if resp = response
            expect(resp.body).to eq("host1 response")
          end
        end
      end

      it "does not match when host differs" do
        options = VCR::CassetteOptions.new
        options[:match_requests_on] = [:host]

        VCR.use_cassette("example", options) do
          # Request to a different host not in cassette
          request = VCR::Request.new("get", "http://unknown-host.com/", nil, {} of String => Array(String))
          response = VCR.http_interactions.response_for(request)

          expect(response).to be_nil
        end
      end
    end
  end
end
