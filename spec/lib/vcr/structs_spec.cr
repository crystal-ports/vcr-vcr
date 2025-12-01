require "../../spec_helper"

Spectator.describe VCR::Request do
  describe ".from_hash" do
    it "constructs request from hash" do
      hash = {
        "method"  => "GET",
        "uri"     => "http://foo.com/",
        "body"    => {"string" => "req body"},
        "headers" => {"bar" => ["foo"]},
      }
      request = VCR::Request.from_hash(hash)
      expect(request.method).to eq("GET")
      expect(request.uri).to eq("http://foo.com/")
      expect(request.body).to eq("req body")
      expect(request.headers["bar"]).to eq(["foo"])
    end
  end

  describe "#parsed_uri" do
    it "parses the URI" do
      request = VCR::Request.new("GET", "http://foo.com/bar?query=1", nil, {} of String => Array(String))
      uri = request.parsed_uri
      expect(uri.host).to eq("foo.com")
      expect(uri.path).to eq("/bar")
      expect(uri.query).to eq("query=1")
    end
  end

  describe "#to_hash" do
    it "returns a hash representation" do
      request = VCR::Request.new("POST", "http://example.com/", "body", {"Content-Type" => ["application/json"]})
      hash = request.to_hash
      expect(hash["method"]).to eq("POST")
      expect(hash["uri"]).to eq("http://example.com/")
      expect(hash["headers"]).to eq({"Content-Type" => ["application/json"]})
    end
  end
end

Spectator.describe VCR::Request::Typed do
  it "delegates to the underlying request" do
    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    typed = VCR::Request::Typed.new(request, :ignored)
    expect(typed.uri).to eq("http://example.com/")
  end

  it "returns the type" do
    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    typed = VCR::Request::Typed.new(request, :ignored)
    expect(typed.type).to eq(:ignored)
  end

  it "returns true for ignored? when type is :ignored" do
    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    typed = VCR::Request::Typed.new(request, :ignored)
    expect(typed.ignored?).to be_true
  end

  it "returns true for real? when type is :ignored or :recordable" do
    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    expect(VCR::Request::Typed.new(request, :ignored).real?).to be_true
    expect(VCR::Request::Typed.new(request, :recordable).real?).to be_true
    expect(VCR::Request::Typed.new(request, :stubbed_by_vcr).real?).to be_false
  end
end

Spectator.describe VCR::Response do
  describe ".from_hash" do
    it "constructs response from hash" do
      hash = {
        "status"  => {"code" => 200, "message" => "OK"},
        "headers" => {"foo" => ["bar"]},
        "body"    => {"string" => "res body"},
      }
      response = VCR::Response.from_hash(hash)
      expect(response.status.code).to eq(200)
      expect(response.status.message).to eq("OK")
      expect(response.body).to eq("res body")
      expect(response.headers["foo"]).to eq(["bar"])
    end
  end

  describe "#update_content_length_header" do
    it "updates the content-length header to match body size" do
      response = VCR::Response.new(
        VCR::ResponseStatus.new(200, "OK"),
        {"Content-Length" => ["0"]},
        "the body"
      )
      response.update_content_length_header
      expect(response.headers["Content-Length"]).to eq(["8"])
    end

    it "sets content-length to 0 when body is nil" do
      response = VCR::Response.new(
        VCR::ResponseStatus.new(200, "OK"),
        {"Content-Length" => ["10"]},
        nil
      )
      response.update_content_length_header
      expect(response.headers["Content-Length"]).to eq(["0"])
    end
  end

  describe "#compressed?" do
    it "returns true for gzip encoding" do
      response = VCR::Response.new(
        VCR::ResponseStatus.new(200, "OK"),
        {"Content-Encoding" => ["gzip"]},
        "body"
      )
      expect(response.compressed?).to be_true
    end

    it "returns true for deflate encoding" do
      response = VCR::Response.new(
        VCR::ResponseStatus.new(200, "OK"),
        {"Content-Encoding" => ["deflate"]},
        "body"
      )
      expect(response.compressed?).to be_true
    end

    it "returns false when no encoding" do
      response = VCR::Response.new(
        VCR::ResponseStatus.new(200, "OK"),
        {} of String => Array(String),
        "body"
      )
      expect(response.compressed?).to be_false
    end
  end
end

Spectator.describe VCR::ResponseStatus do
  describe ".from_hash" do
    it "constructs status from hash" do
      hash = {"code" => 404, "message" => "Not Found"}
      status = VCR::ResponseStatus.from_hash(hash)
      expect(status.code).to eq(404)
      expect(status.message).to eq("Not Found")
    end
  end

  describe "#to_hash" do
    it "returns a hash representation" do
      status = VCR::ResponseStatus.new(201, "Created")
      hash = status.to_hash
      expect(hash["code"]).to eq(201)
      expect(hash["message"]).to eq("Created")
    end
  end
end

Spectator.describe VCR::HTTPInteraction do
  describe ".from_hash" do
    it "constructs interaction from hash" do
      hash = {
        "request" => {
          "method"  => "POST",
          "uri"     => "http://api.example.com/",
          "body"    => {"string" => "request body"},
          "headers" => {"Content-Type" => ["application/json"]},
        },
        "response" => {
          "status"  => {"code" => 201, "message" => "Created"},
          "headers" => {"Content-Type" => ["application/json"]},
          "body"    => {"string" => "response body"},
        },
        "recorded_at" => Time.utc.to_rfc2822,
      }
      interaction = VCR::HTTPInteraction.from_hash(hash)
      expect(interaction.request.method).to eq("POST")
      expect(interaction.response.status.code).to eq(201)
    end
  end

  describe "#to_hash" do
    it "returns a hash representation" do
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
      interaction = VCR::HTTPInteraction.new(request, response)
      hash = interaction.to_hash
      expect(hash["request"]).to be_a(Hash(String, String | Hash(String, String) | Hash(String, Array(String))))
      expect(hash["response"]).to be_truthy
      expect(hash["recorded_at"]).to be_a(String)
    end
  end
end

Spectator.describe VCR::HTTPInteraction::HookAware do
  it "starts as not ignored" do
    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
    interaction = VCR::HTTPInteraction.new(request, response)
    hook_aware = interaction.hook_aware
    expect(hook_aware.ignored?).to be_false
  end

  it "can be ignored" do
    request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
    response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
    interaction = VCR::HTTPInteraction.new(request, response)
    hook_aware = interaction.hook_aware
    hook_aware.ignore!
    expect(hook_aware.ignored?).to be_true
  end

  it "can filter sensitive data" do
    request = VCR::Request.new("GET", "http://secret.example.com/", "secret data", {} of String => Array(String))
    response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "secret response")
    interaction = VCR::HTTPInteraction.new(request, response)
    hook_aware = interaction.hook_aware
    hook_aware.filter!("secret", "FILTERED")
    expect(interaction.request.uri).to eq("http://FILTERED.example.com/")
    expect(interaction.request.body).to eq("FILTERED data")
    expect(interaction.response.body).to eq("FILTERED response")
  end
end
