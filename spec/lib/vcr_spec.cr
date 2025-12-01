require "../spec_helper"

Spectator.describe VCR do
  describe ".insert_cassette" do
    it "creates a new cassette" do
      cassette = VCR.insert_cassette("test_cassette")
      expect(cassette).to be_a(VCR::Cassette)
      VCR.eject_cassette
    end

    it "sets the current_cassette" do
      expect(VCR.current_cassette).to be_nil
      cassette = VCR.insert_cassette("test_cassette")
      expect(VCR.current_cassette).to eq(cassette)
      VCR.eject_cassette
    end

    it "raises an error for duplicate cassette names" do
      VCR.insert_cassette("foo")
      expect { VCR.insert_cassette("foo") }.to raise_error(ArgumentError, /same name/)
      VCR.eject_cassette
    end
  end

  describe ".eject_cassette" do
    it "removes the current cassette" do
      VCR.insert_cassette("test_cassette")
      expect(VCR.current_cassette).not_to be_nil
      VCR.eject_cassette
      expect(VCR.current_cassette).to be_nil
    end

    it "returns the ejected cassette" do
      cassette = VCR.insert_cassette("test_cassette")
      ejected = VCR.eject_cassette
      expect(ejected).to eq(cassette)
    end
  end

  describe ".use_cassette" do
    it "yields with a cassette inserted" do
      VCR.use_cassette("test_cassette") do
        expect(VCR.current_cassette).not_to be_nil
      end
      expect(VCR.current_cassette).to be_nil
    end

    it "ejects the cassette even if an error is raised" do
      begin
        VCR.use_cassette("test_cassette") do
          raise "test error"
        end
      rescue
      end
      expect(VCR.current_cassette).to be_nil
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(VCR.configuration).to be_a(VCR::Configuration)
    end

    it "returns the same instance" do
      expect(VCR.configuration).to be(VCR.configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      yielded = nil
      VCR.configure do |config|
        yielded = config
      end
      expect(yielded).to eq(VCR.configuration)
    end
  end

  describe ".request_matchers" do
    it "returns a RequestMatcherRegistry" do
      expect(VCR.request_matchers).to be_a(VCR::RequestMatcherRegistry)
    end
  end

  describe ".request_ignorer" do
    it "returns a RequestIgnorer" do
      expect(VCR.request_ignorer).to be_a(VCR::RequestIgnorer)
    end
  end

  describe ".cassette_serializers" do
    it "returns a Serializers instance" do
      expect(VCR.cassette_serializers).to be_a(VCR::Cassette::Serializers)
    end
  end

  describe ".cassette_persisters" do
    it "returns a Persisters instance" do
      expect(VCR.cassette_persisters).to be_a(VCR::Cassette::Persisters)
    end
  end

  describe ".turned_on?" do
    it "is on by default" do
      expect(VCR.turned_on?).to be_true
    end
  end

  describe ".turn_off!" do
    it "turns VCR off" do
      VCR.turn_off!
      expect(VCR.turned_on?).to be_false
      VCR.turn_on!
    end

    it "raises if a cassette is in use" do
      VCR.insert_cassette("test")
      expect { VCR.turn_off! }.to raise_error(VCR::Errors::CassetteInUseError)
      VCR.eject_cassette
    end
  end

  describe ".turn_on!" do
    it "turns VCR on" do
      VCR.turn_off!
      VCR.turn_on!
      expect(VCR.turned_on?).to be_true
    end
  end

  describe ".turned_off" do
    it "yields with VCR turned off" do
      VCR.turned_off do
        expect(VCR.turned_on?).to be_false
      end
      expect(VCR.turned_on?).to be_true
    end
  end

  describe ".real_http_connections_allowed?" do
    it "returns false when no cassette is in use and allow_http_connections is false" do
      VCR.configuration.allow_http_connections_when_no_cassette = false
      expect(VCR.real_http_connections_allowed?).to be_false
    end

    it "returns true when allow_http_connections_when_no_cassette is true" do
      VCR.configuration.allow_http_connections_when_no_cassette = true
      expect(VCR.real_http_connections_allowed?).to be_true
      VCR.configuration.allow_http_connections_when_no_cassette = false
    end
  end
end
