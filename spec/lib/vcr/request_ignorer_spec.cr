require "../../spec_helper"

Spectator.describe VCR::RequestIgnorer do
  describe "#ignore?" do
    it "returns false for non-ignored hosts" do
      ignorer = VCR::RequestIgnorer.new
      request = VCR::Request.new("GET", "http://example.com/foo", nil, {} of String => Array(String))
      expect(ignorer.ignore?(request)).to be_false
    end

    it "returns true for ignored hosts" do
      ignorer = VCR::RequestIgnorer.new
      ignorer.ignore_hosts("example.com")
      request = VCR::Request.new("GET", "http://example.com/foo", nil, {} of String => Array(String))
      expect(ignorer.ignore?(request)).to be_true
    end

    it "returns false for subdomains of ignored hosts" do
      ignorer = VCR::RequestIgnorer.new
      ignorer.ignore_hosts("example.com")
      request = VCR::Request.new("GET", "http://www.example.com/foo", nil, {} of String => Array(String))
      expect(ignorer.ignore?(request)).to be_false
    end

    it "handles multiple ignored hosts" do
      ignorer = VCR::RequestIgnorer.new
      ignorer.ignore_hosts("example.com", "example.net")
      request1 = VCR::Request.new("GET", "http://example.com/foo", nil, {} of String => Array(String))
      request2 = VCR::Request.new("GET", "http://example.net/bar", nil, {} of String => Array(String))
      expect(ignorer.ignore?(request1)).to be_true
      expect(ignorer.ignore?(request2)).to be_true
    end
  end

  describe "#unignore_hosts" do
    it "removes hosts from ignored list" do
      ignorer = VCR::RequestIgnorer.new
      ignorer.ignore_hosts("example.com")
      ignorer.unignore_hosts("example.com")
      request = VCR::Request.new("GET", "http://example.com/foo", nil, {} of String => Array(String))
      expect(ignorer.ignore?(request)).to be_false
    end
  end

  describe "#ignore_localhost=" do
    it "ignores localhost aliases when set to true" do
      ignorer = VCR::RequestIgnorer.new
      ignorer.ignore_localhost = true

      VCR::RequestIgnorer::LOCALHOST_ALIASES.each do |host|
        request = VCR::Request.new("GET", "http://#{host}/foo", nil, {} of String => Array(String))
        expect(ignorer.ignore?(request)).to be_true
      end
    end

    it "does not ignore localhost when set to false" do
      ignorer = VCR::RequestIgnorer.new
      ignorer.ignore_localhost = false
      request = VCR::Request.new("GET", "http://localhost/foo", nil, {} of String => Array(String))
      expect(ignorer.ignore?(request)).to be_false
    end
  end

  describe "#ignore_request" do
    it "ignores requests matching custom block" do
      ignorer = VCR::RequestIgnorer.new
      ignorer.ignore_request do |request|
        uri = URI.parse(request.uri)
        uri.port == 5
      end

      request1 = VCR::Request.new("GET", "http://foo.com:5/bar", nil, {} of String => Array(String))
      request2 = VCR::Request.new("GET", "http://foo.com:6/bar", nil, {} of String => Array(String))
      expect(ignorer.ignore?(request1)).to be_true
      expect(ignorer.ignore?(request2)).to be_false
    end
  end
end
