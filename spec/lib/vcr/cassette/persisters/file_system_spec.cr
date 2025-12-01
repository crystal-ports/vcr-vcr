require "../../../../spec_helper"

Spectator.describe VCR::Cassette::Persisters::FileSystem do
  # The FileSystem persister stores cassettes as files on disk.
  # File names are derived from the cassette name, with special characters sanitized.

  describe ".storage_location" do
    it "can be set and retrieved" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      begin
        VCR::Cassette::Persisters::FileSystem.storage_location = "/tmp/vcr_test_cassettes"
        expect(VCR::Cassette::Persisters::FileSystem.storage_location).not_to be_nil
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
      end
    end

    it "creates the directory if it doesn't exist" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      test_dir = "/tmp/vcr_file_system_spec_#{Time.utc.to_unix}"
      begin
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
        expect(Dir.exists?(test_dir)).to be_false

        VCR::Cassette::Persisters::FileSystem.storage_location = test_dir
        expect(Dir.exists?(test_dir)).to be_true
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
        FileUtils.rm_rf(test_dir)
      end
    end

    it "can be set to nil" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      begin
        VCR::Cassette::Persisters::FileSystem.storage_location = nil
        expect(VCR::Cassette::Persisters::FileSystem.storage_location).to be_nil
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
      end
    end
  end

  describe ".[]" do
    it "returns nil if the file does not exist" do
      expect(VCR::Cassette::Persisters::FileSystem["non_existent_file"]).to be_nil
    end

    it "returns nil if storage_location is not set" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      begin
        VCR::Cassette::Persisters::FileSystem.storage_location = nil
        expect(VCR::Cassette::Persisters::FileSystem["any_file"]).to be_nil
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
      end
    end

    it "reads and returns file content when file exists" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      test_dir = "/tmp/vcr_file_system_spec_read_#{Time.utc.to_unix}"
      begin
        VCR::Cassette::Persisters::FileSystem.storage_location = test_dir
        file_path = File.join(test_dir, "test_cassette.yml")
        File.write(file_path, "test content")

        content = VCR::Cassette::Persisters::FileSystem["test_cassette.yml"]
        expect(content).to eq("test content")
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
        FileUtils.rm_rf(test_dir)
      end
    end
  end

  describe ".[]=" do
    it "writes content to a file" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      test_dir = "/tmp/vcr_file_system_spec_write_#{Time.utc.to_unix}"
      begin
        VCR::Cassette::Persisters::FileSystem.storage_location = test_dir

        VCR::Cassette::Persisters::FileSystem["my_cassette.yml"] = "cassette content"

        file_path = File.join(test_dir, "my_cassette.yml")
        expect(File.exists?(file_path)).to be_true
        expect(File.read(file_path)).to eq("cassette content")
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
        FileUtils.rm_rf(test_dir)
      end
    end

    it "creates subdirectories as needed" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      test_dir = "/tmp/vcr_file_system_spec_subdir_#{Time.utc.to_unix}"
      begin
        VCR::Cassette::Persisters::FileSystem.storage_location = test_dir

        VCR::Cassette::Persisters::FileSystem["api/users/list.yml"] = "nested content"

        file_path = File.join(test_dir, "api/users/list.yml")
        expect(File.exists?(file_path)).to be_true
        expect(File.read(file_path)).to eq("nested content")
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
        FileUtils.rm_rf(test_dir)
      end
    end

    it "does nothing when storage_location is nil" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      begin
        VCR::Cassette::Persisters::FileSystem.storage_location = nil

        # This should not raise an error
        VCR::Cassette::Persisters::FileSystem["test.yml"] = "content"
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
      end
    end
  end

  describe ".absolute_path_to_file" do
    it "returns nil if storage_location is not set" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      begin
        VCR::Cassette::Persisters::FileSystem.storage_location = nil
        expect(VCR::Cassette::Persisters::FileSystem.absolute_path_to_file("test.yml")).to be_nil
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
      end
    end

    it "returns the absolute path based on storage location" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      test_dir = "/tmp/vcr_abs_path_test_#{Time.utc.to_unix}"
      begin
        FileUtils.mkdir_p(test_dir)
        VCR::Cassette::Persisters::FileSystem.storage_location = test_dir
        result = VCR::Cassette::Persisters::FileSystem.absolute_path_to_file("test.yml")
        expect(result).not_to be_nil
        expect(result.to_s).to end_with("test.yml")
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
        FileUtils.rm_rf(test_dir)
      end
    end

    it "sanitizes file names with special characters" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      test_dir = "/tmp/vcr_sanitize_test_#{Time.utc.to_unix}"
      begin
        FileUtils.mkdir_p(test_dir)
        VCR::Cassette::Persisters::FileSystem.storage_location = test_dir
        result = VCR::Cassette::Persisters::FileSystem.absolute_path_to_file("test file with spaces.yml")
        expect(result).not_to be_nil
        expect(result.to_s).to contain("test_file_with_spaces.yml")
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
        FileUtils.rm_rf(test_dir)
      end
    end

    it "preserves subdirectory paths" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      test_dir = "/tmp/vcr_subdir_test_#{Time.utc.to_unix}"
      begin
        FileUtils.mkdir_p(test_dir)
        VCR::Cassette::Persisters::FileSystem.storage_location = test_dir
        result = VCR::Cassette::Persisters::FileSystem.absolute_path_to_file("api/users/list.yml")
        expect(result).not_to be_nil
        expect(result.to_s).to contain("api/users/list.yml")
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
        FileUtils.rm_rf(test_dir)
      end
    end
  end

  describe "round-trip read/write" do
    it "can write and then read back content" do
      original = VCR::Cassette::Persisters::FileSystem.storage_location
      test_dir = "/tmp/vcr_roundtrip_test_#{Time.utc.to_unix}"
      begin
        VCR::Cassette::Persisters::FileSystem.storage_location = test_dir

        yaml_content = <<-YAML
        ---
        http_interactions:
        - request:
            method: get
            uri: http://example.com/test
          response:
            status:
              code: 200
              message: OK
            body: Hello, World!
        recorded_with: VCR
        YAML

        VCR::Cassette::Persisters::FileSystem["roundtrip_test.yml"] = yaml_content
        read_content = VCR::Cassette::Persisters::FileSystem["roundtrip_test.yml"]

        expect(read_content).to eq(yaml_content)
      ensure
        VCR::Cassette::Persisters::FileSystem.storage_location = original
        FileUtils.rm_rf(test_dir)
      end
    end
  end
end
