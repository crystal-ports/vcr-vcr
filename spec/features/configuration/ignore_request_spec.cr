require "../../spec_helper"

Spectator.describe "Configuration: Ignore Request" do
  # Configure VCR to ignore certain requests.
  # Ignored requests are not recorded and pass through to the real network.

  describe "RequestIgnorer" do
    it "is available through VCR" do
      expect(VCR.request_ignorer).not_to be_nil
    end

    it "can configure hosts to ignore" do
      VCR.configuration.ignore_hosts("localhost", "127.0.0.1")
      expect(VCR.request_ignorer).not_to be_nil
    end

    it "can configure localhost to be ignored" do
      VCR.configuration.ignore_localhost = true
      # Verify configuration was accepted
      expect(VCR.request_ignorer).not_to be_nil
    end
  end

  describe "ignore_hosts" do
    it "ignores requests to specified hosts" do
      VCR.configuration.ignore_hosts("ignored.example.com")

      headers = {} of String => Array(String)
      ignored_request = VCR::Request.new("get", "http://ignored.example.com/path", nil, headers)

      expect(VCR.request_ignorer.ignore?(ignored_request)).to be_true
    end

    it "does not ignore requests to other hosts" do
      VCR.configuration.ignore_hosts("ignored-only.example.com")

      headers = {} of String => Array(String)
      normal_request = VCR::Request.new("get", "http://other-host.example.com/path", nil, headers)

      # After adding ignore rule, other hosts should still be recorded
      expect(VCR.request_ignorer.ignore?(normal_request)).to be_false
    end
  end

  describe "ignore_localhost" do
    it "when enabled, ignores localhost requests" do
      VCR.configuration.ignore_localhost = true

      headers = {} of String => Array(String)
      localhost_request = VCR::Request.new("get", "http://localhost:3000/api", nil, headers)

      expect(VCR.request_ignorer.ignore?(localhost_request)).to be_true
    end

    it "when enabled, ignores 127.0.0.1 requests" do
      VCR.configuration.ignore_localhost = true

      headers = {} of String => Array(String)
      loopback_request = VCR::Request.new("get", "http://127.0.0.1:3000/api", nil, headers)

      expect(VCR.request_ignorer.ignore?(loopback_request)).to be_true
    end
  end

  describe "ignore_request block" do
    it "can use a block to determine if request should be ignored" do
      VCR.configuration.ignore_request do |request|
        request.uri.includes?("/health")
      end

      headers = {} of String => Array(String)
      health_request = VCR::Request.new("get", "http://api.example.com/health", nil, headers)
      normal_request = VCR::Request.new("get", "http://api.example.com/users", nil, headers)

      expect(VCR.request_ignorer.ignore?(health_request)).to be_true
      expect(VCR.request_ignorer.ignore?(normal_request)).to be_false
    end
  end
end
