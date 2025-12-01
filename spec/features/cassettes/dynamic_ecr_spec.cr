require "../../spec_helper"

Spectator.describe "Dynamic ECR Templates" do
  # VCR cassettes can be treated as ECR (Embedded Crystal) templates,
  # allowing dynamic content in recorded interactions.

  describe "ecr option" do
    it "accepts true to enable ECR processing" do
      options = VCR::CassetteOptions.new
      options[:ecr] = true
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.ecr).to eq(true)
    end

    it "accepts a hash of variables for ECR templates" do
      variables = {"api_key" => "secret123", "user_id" => "42"}
      options = VCR::CassetteOptions.new
      options[:ecr] = variables
      cassette = VCR::Cassette.new("test", options)
      expect(cassette.ecr).to eq(variables)
    end

    it "defaults to nil (ECR disabled)" do
      cassette = VCR::Cassette.new("test", VCR::CassetteOptions.new)
      expect(cassette.ecr).to be_nil
    end
  end

  describe VCR::Cassette::ECRRenderer do
    it "substitutes variables in templates" do
      template = "API Key: <%= api_key %>"
      variables = {"api_key" => "secret123"}
      renderer = VCR::Cassette::ECRRenderer.new(template, variables, "test")
      expect(renderer.render).to eq("API Key: secret123")
    end

    it "raises error for missing variables" do
      template = "API Key: <%= undefined_var %>"
      renderer = VCR::Cassette::ECRRenderer.new(template, true, "test")
      expect { renderer.render }.to raise_error(VCR::Errors::MissingECRVariableError)
    end
  end
end
