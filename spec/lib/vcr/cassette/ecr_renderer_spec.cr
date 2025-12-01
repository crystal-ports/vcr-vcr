require "../../../spec_helper"

Spectator.describe VCR::Cassette::ECRRenderer do
  describe "#render" do
    it "returns raw template when ecr is disabled" do
      renderer = VCR::Cassette::ECRRenderer.new("raw content", false, "test")
      expect(renderer.render).to eq("raw content")
    end

    it "returns nil when template is nil" do
      renderer = VCR::Cassette::ECRRenderer.new(nil, true, "test")
      expect(renderer.render).to be_nil
    end

    it "substitutes variables in template" do
      template = "Hello <%= name %>!"
      variables = {"name" => "World"}
      renderer = VCR::Cassette::ECRRenderer.new(template, variables, "test")
      expect(renderer.render).to eq("Hello World!")
    end

    it "raises error for missing variables" do
      template = "Hello <%= missing %>!"
      renderer = VCR::Cassette::ECRRenderer.new(template, true, "test")
      expect { renderer.render }.to raise_error(VCR::Errors::MissingECRVariableError)
    end

    it "handles multiple variables" do
      template = "<%= var1 %>. ECR with Vars! <%= var2 %>"
      variables = {"var1" => "foo", "var2" => "bar"}
      renderer = VCR::Cassette::ECRRenderer.new(template, variables, "test")
      expect(renderer.render).to eq("foo. ECR with Vars! bar")
    end
  end
end
