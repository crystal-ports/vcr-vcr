require "../../spec_helper"

Spectator.describe "Configuration: URI Parser" do
  # Configure custom URI parsing.
  # VCR uses this to parse URIs for request matching.

  describe "uri_parser" do
    it "is configurable" do
      expect(VCR.configuration).not_to be_nil
    end

    it "defaults to URI class" do
      expect(VCR.configuration.uri_parser).to eq(URI)
    end

    it "can be set to URI class" do
      VCR.configuration.uri_parser = URI
      expect(VCR.configuration.uri_parser).to eq(URI)
    end
  end

  describe "default URI parsing" do
    it "parses HTTP URIs" do
      uri = URI.parse("http://example.com/path")
      expect(uri.scheme).to eq("http")
      expect(uri.host).to eq("example.com")
      expect(uri.path).to eq("/path")
    end

    it "parses HTTPS URIs" do
      uri = URI.parse("https://secure.example.com/api/v1")
      expect(uri.scheme).to eq("https")
      expect(uri.host).to eq("secure.example.com")
      expect(uri.path).to eq("/api/v1")
    end

    it "parses URIs with ports" do
      uri = URI.parse("http://localhost:3000/test")
      expect(uri.host).to eq("localhost")
      expect(uri.port).to eq(3000)
    end

    it "parses URIs with query strings" do
      uri = URI.parse("http://example.com/search?q=test&page=1")
      expect(uri.path).to eq("/search")
      expect(uri.query).to eq("q=test&page=1")
    end

    it "parses URIs with fragments" do
      uri = URI.parse("http://example.com/page#section")
      expect(uri.path).to eq("/page")
      expect(uri.fragment).to eq("section")
    end

    it "parses URIs with authentication" do
      uri = URI.parse("http://user:pass@example.com/")
      expect(uri.user).to eq("user")
      expect(uri.password).to eq("pass")
      expect(uri.host).to eq("example.com")
    end
  end

  describe "URI components for matching" do
    it "extracts host for :host matcher" do
      uri = URI.parse("http://api.example.com/users")
      expect(uri.host).to eq("api.example.com")
    end

    it "extracts path for :path matcher" do
      uri = URI.parse("http://api.example.com/users/123")
      expect(uri.path).to eq("/users/123")
    end

    it "handles URIs without paths" do
      uri = URI.parse("http://example.com")
      expect(uri.path).to eq("")
    end
  end

  describe "URI normalization" do
    it "handles trailing slashes" do
      uri1 = URI.parse("http://example.com/path/")
      uri2 = URI.parse("http://example.com/path")

      expect(uri1.path).to eq("/path/")
      expect(uri2.path).to eq("/path")
    end

    it "handles encoded characters" do
      uri = URI.parse("http://example.com/path%20with%20spaces")
      expect(uri.path).to eq("/path%20with%20spaces")
    end
  end
end
