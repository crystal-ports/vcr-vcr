module VCR
  # @private
  class LibraryHooks
    property exclusive_hook : Symbol?

    def disabled?(hook : Symbol) : Bool
      ![nil, hook].includes?(exclusive_hook)
    end

    def exclusively_enabled(hook : Symbol, &)
      self.exclusive_hook = hook
      yield
    ensure
      self.exclusive_hook = nil
    end
  end
end
