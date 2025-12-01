require "../../spec_helper"

Spectator.describe "Configuration: cassette_library_dir" do
  # The cassette_library_dir configuration option sets a directory
  # where VCR saves each cassette.

  describe "cassette_library_dir" do
    it "can be configured" do
      original = VCR.configuration.cassette_library_dir
      expect(VCR.configuration.cassette_library_dir).to be_a(String)
      VCR.configuration.cassette_library_dir = original
    end

    it "returns the configured directory path" do
      original = VCR.configuration.cassette_library_dir

      VCR.configuration.cassette_library_dir = "/tmp/test_cassettes"
      expect(VCR.configuration.cassette_library_dir).to eq("/tmp/test_cassettes")

      VCR.configuration.cassette_library_dir = original
    end

    it "is used to determine cassette file paths" do
      original = VCR.configuration.cassette_library_dir

      test_dir = File.join(Dir.tempdir, "vcr_test_#{Random.new.hex(4)}")
      FileUtils.mkdir_p(test_dir)

      VCR.configuration.cassette_library_dir = test_dir

      options = VCR::CassetteOptions.new
      options[:record] = :all
      cassette = VCR::Cassette.new("test_path", options)

      file = cassette.file
      expect(file).not_to be_nil
      if f = file
        expect(f).to start_with(test_dir)
        expect(f).to contain("test_path")
      end

      FileUtils.rm_rf(test_dir)
      VCR.configuration.cassette_library_dir = original
    end
  end

  describe "directory creation" do
    it "creates the directory when cassette_library_dir is set" do
      original_dir = VCR.configuration.cassette_library_dir
      test_dir = File.join(Dir.tempdir, "vcr_new_dir_#{Random.new.hex(4)}")

      # Directory should not exist before setting cassette_library_dir
      expect(Dir.exists?(test_dir)).to be_false

      # Setting cassette_library_dir creates the directory
      VCR.configuration.cassette_library_dir = test_dir

      expect(Dir.exists?(test_dir)).to be_true
      FileUtils.rm_rf(test_dir)
      VCR.configuration.cassette_library_dir = original_dir
    end
  end

  describe "nested cassette paths" do
    it "supports nested directory paths in cassette names" do
      original_dir = VCR.configuration.cassette_library_dir
      test_dir = File.join(Dir.tempdir, "vcr_nested_#{Random.new.hex(4)}")
      FileUtils.mkdir_p(test_dir)
      VCR.configuration.cassette_library_dir = test_dir

      options = VCR::CassetteOptions.new
      options[:record] = :all

      VCR.use_cassette("api/v2/users/list", options) do
        cassette = VCR.current_cassette
        expect(cassette).not_to be_nil
        if c = cassette
          file = c.file
          if f = file
            expect(f).to contain("api")
            expect(f).to contain("v2")
            expect(f).to contain("users")
            expect(f).to contain("list")
          end

          # Record to trigger file creation
          request = VCR::Request.new("get", "http://example.com/test", nil, {} of String => Array(String))
          response = VCR::Response.new(VCR::ResponseStatus.new(200, "OK"), {} of String => Array(String), "test")
          interaction = VCR::HTTPInteraction.new(request, response)
          c.record_http_interaction(interaction)
        end
      end

      # Verify nested directories were created
      nested_path = File.join(test_dir, "api", "v2", "users")
      expect(Dir.exists?(nested_path)).to be_true

      FileUtils.rm_rf(test_dir)
      VCR.configuration.cassette_library_dir = original_dir
    end
  end
end
