require "../../spec_helper"

Spectator.describe VCR::Errors do
  describe VCR::Errors::UnhandledHTTPRequestError do
    it "creates an error with request details" do
      request = VCR::Request.new("POST", "http://foo.com/", nil, {} of String => Array(String))
      error = VCR::Errors::UnhandledHTTPRequestError.new(request)
      message = error.message
      expect(message).not_to be_nil
      if msg = message
        expect(msg).to contain("POST http://foo.com/")
      end
    end

    it "mentions that there is no cassette when no cassette is in use" do
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      error = VCR::Errors::UnhandledHTTPRequestError.new(request)
      message = error.message
      expect(message).not_to be_nil
      if msg = message
        expect(msg).to contain("There is currently no cassette in use.")
      end
    end

    it "mentions the allow_http_connections_when_no_cassette option" do
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      error = VCR::Errors::UnhandledHTTPRequestError.new(request)
      message = error.message
      expect(message).not_to be_nil
      if msg = message
        expect(msg).to contain("allow_http_connections_when_no_cassette")
      end
    end

    it "mentions the ignore_request callback" do
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      error = VCR::Errors::UnhandledHTTPRequestError.new(request)
      message = error.message
      expect(message).not_to be_nil
      if msg = message
        expect(msg).to contain("ignore_request")
      end
    end

    it "mentions the debug_logger option" do
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      error = VCR::Errors::UnhandledHTTPRequestError.new(request)
      message = error.message
      expect(message).not_to be_nil
      if msg = message
        expect(msg).to contain("debug_logger")
      end
    end
  end

  describe VCR::Errors::CassetteInUseError do
    it "is an Error" do
      expect(VCR::Errors::CassetteInUseError.new("test")).to be_a(VCR::Errors::Error)
    end
  end

  describe VCR::Errors::TurnedOffError do
    it "is an Error" do
      expect(VCR::Errors::TurnedOffError.new("test")).to be_a(VCR::Errors::Error)
    end
  end

  describe VCR::Errors::MissingECRVariableError do
    it "is an Error" do
      expect(VCR::Errors::MissingECRVariableError.new("test")).to be_a(VCR::Errors::Error)
    end
  end

  describe VCR::Errors::UnusedHTTPInteractionError do
    it "is an Error" do
      expect(VCR::Errors::UnusedHTTPInteractionError.new("test")).to be_a(VCR::Errors::Error)
    end
  end
end
