require "./spec_helper"
require "http/client"

Spectator.describe VCR do
  describe ".configure" do
    it "yields configuration" do
      configured = false
      VCR.configure do |c|
        configured = true
        expect(c).to be_a(VCR::Configuration)
      end
      expect(configured).to be_true
    end
  end

  describe ".configuration" do
    it "returns configuration" do
      expect(VCR.configuration).to be_a(VCR::Configuration)
    end
  end

  describe ".use_cassette" do
    it "executes the block with a cassette" do
      Dir.mkdir_p("spec/fixtures/vcr_cassettes")

      cassette_used = false
      VCR.use_cassette("test_cassette") do
        cassette_used = true
        expect(VCR.current_cassette).not_to be_nil
      end
      expect(cassette_used).to be_true
    ensure
      FileUtils.rm_rf("spec/fixtures/vcr_cassettes")
    end
  end

  describe ".turned_on?" do
    it "returns true by default" do
      expect(VCR.turned_on?).to be_true
    end
  end

  describe ".turn_off!" do
    it "turns VCR off" do
      VCR.turn_off!
      expect(VCR.turned_on?).to be_false
    ensure
      VCR.turn_on!
    end
  end

  describe ".turn_on!" do
    it "turns VCR back on" do
      VCR.turn_off!
      VCR.turn_on!
      expect(VCR.turned_on?).to be_true
    end
  end
end

Spectator.describe VCR::Request do
  describe ".from_hash" do
    it "constructs request from hash" do
      hash = {
        "method"  => "GET",
        "uri"     => "https://example.com/api",
        "body"    => {"string" => "test body"},
        "headers" => {"Content-Type" => ["application/json"]},
      }
      request = VCR::Request.from_hash(hash)
      expect(request.method).to eq("GET")
      expect(request.uri).to eq("https://example.com/api")
      expect(request.body).to eq("test body")
      expect(request.headers["Content-Type"]).to eq(["application/json"])
    end
  end

  describe "#parsed_uri" do
    it "returns parsed URI" do
      request = VCR::Request.new("GET", "https://example.com/path?query=value", nil, {} of String => Array(String))
      uri = request.parsed_uri
      expect(uri.host).to eq("example.com")
      expect(uri.path).to eq("/path")
      expect(uri.query).to eq("query=value")
    end
  end
end

Spectator.describe VCR::Response do
  describe ".from_hash" do
    it "constructs response from hash" do
      hash = {
        "status"  => {"code" => 200, "message" => "OK"},
        "headers" => {"Content-Type" => ["text/plain"]},
        "body"    => {"string" => "response body"},
      }
      response = VCR::Response.from_hash(hash)
      expect(response.status.code).to eq(200)
      expect(response.status.message).to eq("OK")
      expect(response.body).to eq("response body")
    end
  end
end

Spectator.describe VCR::HTTPInteraction do
  describe ".from_hash" do
    it "constructs interaction from hash" do
      hash = {
        "request" => {
          "method"  => "POST",
          "uri"     => "https://api.example.com/data",
          "body"    => {"string" => "{\"key\":\"value\"}"},
          "headers" => {"Content-Type" => ["application/json"]},
        },
        "response" => {
          "status"  => {"code" => 201, "message" => "Created"},
          "headers" => {"Content-Type" => ["application/json"]},
          "body"    => {"string" => "{\"id\":123}"},
        },
        "recorded_at" => Time.utc.to_rfc2822,
      }
      interaction = VCR::HTTPInteraction.from_hash(hash)
      expect(interaction.request.method).to eq("POST")
      expect(interaction.response.status.code).to eq(201)
    end
  end
end
