require "../../spec_helper"

Spectator.describe "Cassette Naming" do
  # VCR uses the cassette name to determine the file path for storage.
  # Names can include subdirectories and special characters (within filesystem limits).

  describe "cassette name" do
    it "stores the name" do
      cassette = VCR::Cassette.new("my_cassette", VCR::CassetteOptions.new)
      expect(cassette.name).to eq("my_cassette")
    end

    it "allows subdirectory paths in names" do
      cassette = VCR::Cassette.new("api/users/list", VCR::CassetteOptions.new)
      expect(cassette.name).to eq("api/users/list")
    end

    it "supports special characters that are valid in file names" do
      cassette = VCR::Cassette.new("test-cassette_v2", VCR::CassetteOptions.new)
      expect(cassette.name).to eq("test-cassette_v2")
    end
  end

  describe "file path generation" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "generates a file path from the cassette name" do
      options = VCR::CassetteOptions.new
      options[:record] = :all

      VCR.use_cassette("simple_name", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          file = c.file
          expect(file).not_to be_nil
          if f = file
            expect(f).to contain("simple_name")
            expect(f).to end_with(".yml")
          end
        end
      end
    end

    it "creates subdirectories for nested cassette names" do
      options = VCR::CassetteOptions.new
      options[:record] = :all

      VCR.use_cassette("api/v2/users", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.file).to contain("api")
          expect(c.file).to contain("v2")
          expect(c.file).to contain("users")
        end
      end
    end

    it "handles names with hyphens and underscores" do
      options = VCR::CassetteOptions.new
      options[:record] = :all

      VCR.use_cassette("my-api_test-cassette", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          expect(c.file).to contain("my-api_test-cassette")
        end
      end
    end
  end

  describe "cassette file operations" do
    around_each do |example|
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
      FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
      example.run
      FileUtils.rm_rf(SPEC_CASSETTE_DIR)
    end

    it "loads cassette from the generated file path" do
      # Create a cassette file manually
      cassette_content = <<-YAML
      ---
      http_interactions:
      - request:
          method: get
          uri: http://example.com/test
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
            - "4"
          body:
            encoding: UTF-8
            string: test
          http_version: "1.1"
        recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
      recorded_with: VCR 2.0.0
      YAML

      create_cassette_file("named_cassette", cassette_content)

      VCR.use_cassette("named_cassette") do
        request = VCR::Request.new("get", "http://example.com/test", nil, {} of String => Array(String))
        response = VCR.http_interactions.response_for(request)

        expect(response).not_to be_nil
        if resp = response
          expect(resp.body).to eq("test")
        end
      end
    end

    it "creates nested directory structure when recording" do
      options = VCR::CassetteOptions.new
      options[:record] = :all

      VCR.use_cassette("deep/nested/path/cassette", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          # Record an interaction to trigger file creation
          request = VCR::Request.new("get", "http://example.com/deep", nil, {} of String => Array(String))
          response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "deep response")
          interaction = VCR::HTTPInteraction.new(request, response)
          c.record_http_interaction(interaction)
        end
      end

      # Verify the nested path was created
      nested_path = File.join(SPEC_CASSETTE_DIR, "deep", "nested", "path")
      expect(Dir.exists?(nested_path)).to be_true
    end
  end
end
