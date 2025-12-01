require "../../../spec_helper"

Spectator.describe VCR::VersionChecker do
  describe "#check_version!" do
    it "does not raise when version meets minimum" do
      checker = VCR::VersionChecker.new("test_lib", "2.0.0", "1.0.0")
      checker.check_version! # should not raise
    end

    it "does not raise when version equals minimum" do
      checker = VCR::VersionChecker.new("test_lib", "1.0.0", "1.0.0")
      checker.check_version! # should not raise
    end

    it "raises when major version is too low" do
      checker = VCR::VersionChecker.new("test_lib", "0.9.0", "1.0.0")
      expect { checker.check_version! }.to raise_error(VCR::Errors::LibraryVersionTooLowError)
    end

    it "raises when minor version is too low" do
      checker = VCR::VersionChecker.new("test_lib", "1.0.0", "1.1.0")
      expect { checker.check_version! }.to raise_error(VCR::Errors::LibraryVersionTooLowError)
    end

    it "raises when patch version is too low" do
      checker = VCR::VersionChecker.new("test_lib", "1.0.0", "1.0.1")
      expect { checker.check_version! }.to raise_error(VCR::Errors::LibraryVersionTooLowError)
    end

    it "includes library name and version in error message" do
      checker = VCR::VersionChecker.new("my_library", "0.5.0", "1.0.0")
      begin
        checker.check_version!
        fail "Expected LibraryVersionTooLowError"
      rescue ex : VCR::Errors::LibraryVersionTooLowError
        message = ex.message
        if message
          expect(message).to contain("my_library")
          expect(message).to contain("0.5.0")
          expect(message).to contain(">= 1.0.0")
        else
          fail "Expected error message"
        end
      end
    end
  end
end
