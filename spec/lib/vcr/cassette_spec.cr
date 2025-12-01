require "../../spec_helper"

Spectator.describe VCR::Cassette do
  describe ".new" do
    it "creates a cassette with a name" do
      cassette = VCR::Cassette.new("test_cassette")
      expect(cassette.name).to eq("test_cassette")
    end

    it "raises an error for invalid record mode" do
      expect { VCR::Cassette.new("test", {:record => :invalid_mode}) }.to raise_error(ArgumentError)
    end

    it "raises an error for invalid options" do
      expect { VCR::Cassette.new("test", {:invalid_option => true}) }.to raise_error(ArgumentError)
    end
  end

  describe "#record_mode" do
    it "defaults to :once" do
      cassette = VCR::Cassette.new("test")
      expect(cassette.record_mode).to eq(:once)
    end

    it "can be set to :all" do
      cassette = VCR::Cassette.new("test", {:record => :all})
      expect(cassette.record_mode).to eq(:all)
    end

    it "can be set to :none" do
      cassette = VCR::Cassette.new("test", {:record => :none})
      expect(cassette.record_mode).to eq(:none)
    end

    it "can be set to :new_episodes" do
      cassette = VCR::Cassette.new("test", {:record => :new_episodes})
      expect(cassette.record_mode).to eq(:new_episodes)
    end
  end

  describe "#match_requests_on" do
    it "defaults to [:method, :uri]" do
      cassette = VCR::Cassette.new("test")
      expect(cassette.match_requests_on).to eq([:method, :uri])
    end

    it "can be customized" do
      cassette = VCR::Cassette.new("test", {:match_requests_on => [:method, :uri, :body]})
      expect(cassette.match_requests_on).to eq([:method, :uri, :body])
    end
  end

  describe "#recording?" do
    it "returns true for :all mode" do
      cassette = VCR::Cassette.new("test", {:record => :all})
      expect(cassette.recording?).to be_true
    end

    it "returns true for :new_episodes mode" do
      cassette = VCR::Cassette.new("test", {:record => :new_episodes})
      expect(cassette.recording?).to be_true
    end

    it "returns false for :none mode" do
      cassette = VCR::Cassette.new("test", {:record => :none})
      expect(cassette.recording?).to be_false
    end
  end

  describe "#record_http_interaction" do
    it "adds interaction to new_recorded_interactions" do
      cassette = VCR::Cassette.new("test")
      expect(cassette.new_recorded_interactions.size).to eq(0)

      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
      interaction = VCR::HTTPInteraction.new(request, response)

      cassette.record_http_interaction(interaction)
      expect(cassette.new_recorded_interactions.size).to eq(1)
    end
  end

  describe "#serializable_hash" do
    it "returns a hash with http_interactions and recorded_with" do
      cassette = VCR::Cassette.new("test")

      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
      interaction = VCR::HTTPInteraction.new(request, response)
      cassette.record_http_interaction(interaction)

      hash = cassette.serializable_hash
      expect(hash.has_key?("http_interactions")).to be_true
      expect(hash.has_key?("recorded_with")).to be_true
      expect(hash["recorded_with"].as(String)).to contain("VCR")
    end
  end

  describe "#run_failed!" do
    it "marks the cassette as failed" do
      cassette = VCR::Cassette.new("test")
      expect(cassette.run_failed?).to be_false
      cassette.run_failed!
      expect(cassette.run_failed?).to be_true
    end
  end
end
