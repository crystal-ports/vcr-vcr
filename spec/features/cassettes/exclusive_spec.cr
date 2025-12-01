require "../../spec_helper"

Spectator.describe "Exclusive Cassette" do
  # The exclusive option tells VCR to ignore any parent cassettes
  # and only use this cassette for request matching.

  # Given cassettes with different requests:
  PARENT_CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: get
      uri: http://example.com/parent
      body:
        encoding: UTF-8
        string: ""
      headers: {}
    response:
      status:
        code: 200
        message: OK
      headers:
        Content-Length:
        - "15"
      body:
        encoding: UTF-8
        string: parent response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML

  CHILD_CASSETTE_YAML = <<-YAML
  ---
  http_interactions:
  - request:
      method: get
      uri: http://example.com/child
      body:
        encoding: UTF-8
        string: ""
      headers: {}
    response:
      status:
        code: 200
        message: OK
      headers:
        Content-Length:
        - "14"
      body:
        encoding: UTF-8
        string: child response
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:45 GMT
  recorded_with: VCR 2.0.0
  YAML

  describe "exclusive option" do
    it "defaults to false" do
      options = VCR::CassetteOptions.new
      expect(options[:exclusive]?).to be_falsey
    end

    it "can be enabled" do
      options = VCR::CassetteOptions.new
      options[:exclusive] = true
      VCR::Cassette.new("test", options)
      expect(options[:exclusive]?).to be_true
    end
  end

  describe "nested cassette behavior" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("parent", PARENT_CASSETTE_YAML)
      create_cassette_file("child", CHILD_CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "non-exclusive nested cassette can access parent cassette interactions" do
      VCR.use_cassette("parent") do
        # Parent cassette is active
        parent_request = VCR::Request.new("get", "http://example.com/parent", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(parent_request)
        expect(response).not_to be_nil
        if resp = response
          expect(resp.body).to eq("parent response")
        end

        # Insert non-exclusive nested cassette
        options = VCR::CassetteOptions.new
        options[:exclusive] = false

        VCR.use_cassette("child", options) do
          # Child cassette interactions work
          child_request = VCR::Request.new("get", "http://example.com/child", nil, {} of String => Array(String))
          child_response = VCR.http_interactions.response_for(child_request)
          expect(child_response).not_to be_nil
          if resp = child_response
            expect(resp.body).to eq("child response")
          end
        end
      end
    end

    it "exclusive cassette does not access parent cassette interactions" do
      VCR.use_cassette("parent") do
        # Parent cassette is active
        parent_request = VCR::Request.new("get", "http://example.com/parent", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(parent_request)
        expect(response).not_to be_nil

        # Insert exclusive nested cassette
        options = VCR::CassetteOptions.new
        options[:exclusive] = true

        VCR.use_cassette("child", options) do
          # Child cassette interactions work
          child_request = VCR::Request.new("get", "http://example.com/child", nil, {} of String => Array(String))
          child_response = VCR.http_interactions.response_for(child_request)
          expect(child_response).not_to be_nil
          if resp = child_response
            expect(resp.body).to eq("child response")
          end

          # Parent cassette interactions are not accessible (exclusive mode)
          parent_request2 = VCR::Request.new("get", "http://example.com/parent", nil, {} of String => Array(String))
          parent_response = VCR.http_interactions.response_for(parent_request2)
          # In exclusive mode, parent interactions are hidden
          expect(parent_response).to be_nil
        end
      end
    end
  end

  describe "cassette stack" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      create_cassette_file("outer", PARENT_CASSETTE_YAML)
      create_cassette_file("inner", CHILD_CASSETTE_YAML)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "tracks cassette nesting correctly" do
      expect(VCR.current_cassette).to be_nil

      VCR.use_cassette("outer") do
        outer = VCR.current_cassette
        expect(outer).not_to be_nil

        VCR.use_cassette("inner") do
          inner = VCR.current_cassette
          expect(inner).not_to be_nil
          expect(inner).not_to eq(outer) if inner && outer
        end

        # After inner cassette ejected, outer is current again
        expect(VCR.current_cassette).to eq(outer)
      end

      expect(VCR.current_cassette).to be_nil
    end
  end
end
