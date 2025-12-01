require "./util/logger"

module VCR
  # @private
  class RequestHandler
    include Logger::Mixin

    def handle
      log "Handling request: #{request_summary} (disabled: #{disabled?})"
      invoke_before_request_hook

      req_type = request_type(:consume_stub)

      log "Identified request type (#{req_type}) for #{request_summary}"

      # The before_request hook can change the type of request
      # (i.e. by inserting a cassette), so we need to query the
      # request type again.
      #
      # Likewise, the main handler logic can modify what
      # #request_type would return (i.e. when a response stub is
      # used), so we need to store the request type for the
      # after_request hook.
      set_typed_request_for_after_hook(req_type)

      # Dispatch to appropriate handler based on request type
      case req_type
      when :externally_stubbed then on_externally_stubbed_request
      when :ignored            then on_ignored_request
      when :stubbed_by_vcr     then on_stubbed_by_vcr_request
      when :recordable         then on_recordable_request
      when :unhandled          then on_unhandled_request
      end
    end

    private def set_typed_request_for_after_hook(request_type)
      @after_hook_typed_request = Request::Typed.new(vcr_request, request_type)
    end

    private def request_type(consume_stub : Bool = false)
      case
      when externally_stubbed?
        :externally_stubbed
      when should_ignore?
        :ignored
      when has_response_stub?(consume_stub)
        :stubbed_by_vcr
      when VCR.real_http_connections_allowed?
        :recordable
      else :unhandled
      end
    end

    private def invoke_before_request_hook
      return if disabled? || !VCR.configuration.has_hooks_for?(:before_http_request)
      typed_request = Request::Typed.new(vcr_request, request_type)
      VCR.configuration.invoke_hook(:before_http_request, typed_request)
    end

    private def invoke_after_request_hook(vcr_response)
      return if disabled?
      VCR.configuration.invoke_hook(:after_http_request, @after_hook_typed_request, vcr_response)
    end

    private def externally_stubbed?
      false
    end

    private def should_ignore?
      disabled? || VCR.request_ignorer.ignore?(vcr_request)
    end

    private def disabled?
      VCR.library_hooks.disabled?(library_name)
    end

    private def has_response_stub?(consume_stub)
      if consume_stub
        stubbed_response
      else
        VCR.http_interactions.has_interaction_matching?(vcr_request)
      end
    end

    private def stubbed_response
      @stubbed_response ||= VCR.http_interactions.response_for(vcr_request)
    end

    private def library_name : Symbol
      @library_name ||= begin
        parts = self.class.name.split("::")
        parts.size >= 2 ? parts[-2].downcase : "vcr"
      end.to_s
      # Note: Crystal doesn't have to_sym on strings, using string as identifier
      :http_client # Default to :http_client for Crystal's stdlib
    end

    # Subclasses can implement these
    private def on_externally_stubbed_request
    end

    private def on_ignored_request
    end

    private def on_stubbed_by_vcr_request
    end

    private def on_recordable_request
    end

    private def on_unhandled_request
      raise VCR::Errors::UnhandledHTTPRequestError.new(vcr_request)
    end

    private def request_summary
      request_matchers = if cass = VCR.current_cassette
                           cass.match_requests_on
                         else
                           VCR.configuration.default_cassette_options[:match_requests_on]
                         end

      super(vcr_request, request_matchers)
    end

    private def log_prefix
      "[#{library_name}] "
    end
  end
end
