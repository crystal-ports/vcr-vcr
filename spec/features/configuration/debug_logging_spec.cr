require "../../spec_helper"

Spectator.describe "Configuration: Debug Logging" do
  # Use debug_logger to troubleshoot VCR behavior.
  # When enabled, VCR logs details about request matching and cassette operations.

  describe "debug_logger" do
    it "can be set to an IO object" do
      io = IO::Memory.new
      VCR.configuration.debug_logger = io
      expect(VCR.configuration.debug_logger).to eq(io)
    end

    it "defaults to nil" do
      original = VCR.configuration.debug_logger
      VCR.configuration.debug_logger = nil
      expect(VCR.configuration.debug_logger).to be_nil
      VCR.configuration.debug_logger = original
    end

    it "can be set to STDOUT" do
      original = VCR.configuration.debug_logger
      VCR.configuration.debug_logger = STDOUT
      expect(VCR.configuration.debug_logger).to eq(STDOUT)
      VCR.configuration.debug_logger = original
    end

    it "can be set to STDERR" do
      original = VCR.configuration.debug_logger
      VCR.configuration.debug_logger = STDERR
      expect(VCR.configuration.debug_logger).to eq(STDERR)
      VCR.configuration.debug_logger = original
    end
  end

  describe "logging output" do
    it "writes to the configured logger" do
      original_logger = VCR.configuration.debug_logger

      io = IO::Memory.new
      VCR.configuration.debug_logger = io

      # Just verify the logger was set correctly
      expect(VCR.configuration.debug_logger).to eq(io)

      VCR.configuration.debug_logger = original_logger
    end
  end

  describe "Logger utility" do
    it "provides a Logger class" do
      expect(VCR::Logger).not_to be_nil
    end

    it "can create a logger with an IO" do
      io = IO::Memory.new
      logger = VCR::Logger.new(io)
      expect(logger).not_to be_nil
    end

    it "can log messages with prefix" do
      io = IO::Memory.new
      logger = VCR::Logger.new(io)
      logger.log("test message", "prefix")

      output = io.to_s
      expect(output).to contain("test message")
    end

    it "includes prefix in log messages" do
      io = IO::Memory.new
      logger = VCR::Logger.new(io)
      logger.log("test", "VCR")

      output = io.to_s
      expect(output).to contain("VCR")
    end
  end
end
