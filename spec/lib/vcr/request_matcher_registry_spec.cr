require "../../spec_helper"

Spectator.describe VCR::RequestMatcherRegistry do
  describe "#register" do
    it "registers a custom matcher" do
      registry = VCR::RequestMatcherRegistry.new
      registry.register(:my_matcher) { |r1, r2| true }
      expect(registry[:my_matcher]).not_to be_nil
    end
  end

  describe "#[]" do
    it "returns a registered matcher" do
      registry = VCR::RequestMatcherRegistry.new
      expect(registry[:method]).not_to be_nil
    end

    it "raises an error for unregistered matchers" do
      registry = VCR::RequestMatcherRegistry.new
      expect { registry[:unknown_matcher] }.to raise_error(VCR::Errors::UnregisteredMatcherError)
    end
  end

  describe "built-in matchers" do
    describe ":method" do
      it "matches when methods are the same" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
        r2 = VCR::Request.new("GET", "http://other.com/", nil, {} of String => Array(String))
        expect(registry[:method].matches?(r1, r2)).to be_true
      end

      it "does not match when methods differ" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
        r2 = VCR::Request.new("POST", "http://example.com/", nil, {} of String => Array(String))
        expect(registry[:method].matches?(r1, r2)).to be_false
      end
    end

    describe ":uri" do
      it "matches when URIs are the same" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("GET", "http://example.com/foo", nil, {} of String => Array(String))
        r2 = VCR::Request.new("GET", "http://example.com/foo", nil, {} of String => Array(String))
        expect(registry[:uri].matches?(r1, r2)).to be_true
      end

      it "does not match when URIs differ" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("GET", "http://example.com/foo", nil, {} of String => Array(String))
        r2 = VCR::Request.new("GET", "http://example.com/bar", nil, {} of String => Array(String))
        expect(registry[:uri].matches?(r1, r2)).to be_false
      end
    end

    describe ":host" do
      it "matches when hosts are the same" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("GET", "http://example.com/foo", nil, {} of String => Array(String))
        r2 = VCR::Request.new("GET", "http://example.com/bar", nil, {} of String => Array(String))
        expect(registry[:host].matches?(r1, r2)).to be_true
      end

      it "does not match when hosts differ" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("GET", "http://foo.com/", nil, {} of String => Array(String))
        r2 = VCR::Request.new("GET", "http://bar.com/", nil, {} of String => Array(String))
        expect(registry[:host].matches?(r1, r2)).to be_false
      end
    end

    describe ":body" do
      it "matches when bodies are the same" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("POST", "http://example.com/", "body", {} of String => Array(String))
        r2 = VCR::Request.new("POST", "http://example.com/", "body", {} of String => Array(String))
        expect(registry[:body].matches?(r1, r2)).to be_true
      end

      it "does not match when bodies differ" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("POST", "http://example.com/", "body1", {} of String => Array(String))
        r2 = VCR::Request.new("POST", "http://example.com/", "body2", {} of String => Array(String))
        expect(registry[:body].matches?(r1, r2)).to be_false
      end
    end

    describe ":headers" do
      it "matches when headers are the same" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("GET", "http://example.com/", nil, {"X-Custom" => ["value"]})
        r2 = VCR::Request.new("GET", "http://example.com/", nil, {"X-Custom" => ["value"]})
        expect(registry[:headers].matches?(r1, r2)).to be_true
      end

      it "does not match when headers differ" do
        registry = VCR::RequestMatcherRegistry.new
        r1 = VCR::Request.new("GET", "http://example.com/", nil, {"X-Custom" => ["value1"]})
        r2 = VCR::Request.new("GET", "http://example.com/", nil, {"X-Custom" => ["value2"]})
        expect(registry[:headers].matches?(r1, r2)).to be_false
      end
    end
  end
end
