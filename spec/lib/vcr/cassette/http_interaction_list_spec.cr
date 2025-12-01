require "../../../spec_helper"

Spectator.describe VCR::Cassette::HTTPInteractionList do
  describe "#response_for" do
    it "returns nil when the list is empty" do
      list = VCR::Cassette::HTTPInteractionList.new([] of VCR::HTTPInteraction, [:method])
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      expect(list.response_for(request)).to be_nil
    end

    it "returns the matching interaction's response" do
      request = VCR::Request.new("POST", "http://example.com/", nil, {} of String => Array(String))
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "response body")
      interaction = VCR::HTTPInteraction.new(request, response)

      list = VCR::Cassette::HTTPInteractionList.new([interaction], [:method])

      matching_request = VCR::Request.new("POST", "http://other.com/", nil, {} of String => Array(String))
      result = list.response_for(matching_request)
      expect(result).not_to be_nil
      expect(result.try(&.body)).to eq("response body")
    end

    it "returns nil when no interaction matches" do
      request = VCR::Request.new("POST", "http://example.com/", nil, {} of String => Array(String))
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "response body")
      interaction = VCR::HTTPInteraction.new(request, response)

      list = VCR::Cassette::HTTPInteractionList.new([interaction], [:method])

      non_matching_request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      expect(list.response_for(non_matching_request)).to be_nil
    end
  end

  describe "#has_interaction_matching?" do
    it "returns false for empty list" do
      list = VCR::Cassette::HTTPInteractionList.new([] of VCR::HTTPInteraction, [:method])
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      expect(list.has_interaction_matching?(request)).to be_false
    end

    it "returns true when there is a matching interaction" do
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
      interaction = VCR::HTTPInteraction.new(request, response)

      list = VCR::Cassette::HTTPInteractionList.new([interaction], [:method])
      expect(list.has_interaction_matching?(request)).to be_true
    end
  end

  describe "#remaining_unused_interaction_count" do
    it "returns the number of unused interactions" do
      request1 = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      response1 = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body1")
      request2 = VCR::Request.new("POST", "http://example.com/", nil, {} of String => Array(String))
      response2 = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body2")

      list = VCR::Cassette::HTTPInteractionList.new([
        VCR::HTTPInteraction.new(request1, response1),
        VCR::HTTPInteraction.new(request2, response2),
      ], [:method])

      expect(list.remaining_unused_interaction_count).to eq(2)
      list.response_for(request1)
      expect(list.remaining_unused_interaction_count).to eq(1)
    end
  end

  describe "#assert_no_unused_interactions!" do
    it "raises when there are unused interactions" do
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
      interaction = VCR::HTTPInteraction.new(request, response)

      list = VCR::Cassette::HTTPInteractionList.new([interaction], [:method])

      expect { list.assert_no_unused_interactions! }.to raise_error(VCR::Errors::UnusedHTTPInteractionError)
    end

    it "does not raise when all interactions are used" do
      request = VCR::Request.new("GET", "http://example.com/", nil, {} of String => Array(String))
      response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "body")
      interaction = VCR::HTTPInteraction.new(request, response)

      list = VCR::Cassette::HTTPInteractionList.new([interaction], [:method])
      list.response_for(request)

      # Should not raise
      list.assert_no_unused_interactions!
    end
  end
end
