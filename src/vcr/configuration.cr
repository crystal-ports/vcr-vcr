require "./util/hooks"
require "uri"

require "./util/logger"
require "./util/variable_args_block_caller"

module VCR
  # Stores the VCR configuration.
  class Configuration
    include Hooks
    include VariableArgsBlockCaller
    include Logger::Mixin

    # Explicit type declarations for instance variables
    @debug_logger : IO?
    @logger : Logger | Logger::Null.class
    @uri_parser : URI.class
    @query_parser : Proc(String, Hash(String, Array(String)))?
    @allow_http_connections_when_no_cassette : Bool
    @rspec_metadata_configured : Bool
    @default_cassette_options : CassetteOptions
    @preserve_exact_body_bytes_hooks : Array(Proc(Request | Response, Cassette?, Bool))?

    # Gets the directory to read cassettes from and write cassettes to.
    #
    # @return [String] the directory to read cassettes from and write cassettes to
    def cassette_library_dir
      VCR.cassette_persisters[:file_system].storage_location
    end

    # Sets the directory to read cassettes from and writes cassettes to.
    #
    # @example
    #   VCR.configure do |c|
    #     c.cassette_library_dir = 'spec/cassettes'
    #   end
    #
    # @param dir [String] the directory to read cassettes from and write cassettes to
    # @return [void]
    # @note This is only necessary if you use the `:file_system`
    #   cassette persister (the default).
    def cassette_library_dir=(dir)
      VCR.cassette_persisters[:file_system].storage_location = dir
    end

    getter default_cassette_options

    # Sets the default options that apply to every cassette.
    def default_cassette_options=(overrides)
      @default_cassette_options.merge!(overrides)
    end

    # Configures which libraries VCR will hook into to intercept HTTP requests.
    #
    # @example
    #   VCR.configure do |c|
    #     c.hook_into :webmock, :typhoeus
    #   end
    #
    # @param hooks [Array<Symbol>] List of libraries. Valid values are
    #  `:webmock`, `:typhoeus`, `:excon` and `:faraday`.
    # @raise [ArgumentError] when given an unsupported library name.
    # @raise [VCR::Errors::LibraryVersionTooLowError] when the version
    #  of a library you are using is too low for VCR to support.
    def hook_into(*hooks : Array)
      hooks.each { |a| load_library_hook(a) }
      invoke_hook(:after_library_hooks_loaded)
    end

    # Specifies host(s) that VCR should ignore.
    #
    # @param hosts [Array<String>] List of hosts to ignore
    # @see #ignore_localhost=
    # @see #ignore_request
    def ignore_hosts(*hosts)
      VCR.request_ignorer.ignore_hosts(*hosts)
    end

    def ignore_host
      ignore_hosts
    end

    # Specifies host(s) that VCR should stop ignoring.
    #
    # @param hosts [Array<String>] List of hosts to unignore
    # @see #ignore_hosts
    def unignore_hosts(*hosts)
      VCR.request_ignorer.unignore_hosts(*hosts)
    end

    def unignore_host
      unignore_hosts
    end

    # Sets whether or not VCR should ignore localhost requests.
    #
    # @param value [Boolean] the value to set
    # @see #ignore_hosts
    # @see #ignore_request
    def ignore_localhost=(value)
      VCR.request_ignorer.ignore_localhost = value
    end

    # Defines what requests to ignore using a block.
    #
    # @example
    #   VCR.configure do |c|
    #     c.ignore_request do |request|
    #       uri = URI(request.uri)
    #       # ignore only localhost requests to port 7500
    #       uri.host == 'localhost' && uri.port == 7500
    #     end
    #   end
    #
    # @yield the callback
    # @yieldparam request [VCR::Request] the HTTP request
    # @yieldreturn [Boolean] whether or not to ignore the request
    def ignore_request(&block : VCR::Request -> Bool)
      VCR.request_ignorer.ignore_request(&block)
    end

    setter allow_http_connections_when_no_cassette

    # @private (documented above)
    def allow_http_connections_when_no_cassette?
      !!@allow_http_connections_when_no_cassette
    end

    property query_parser

    property uri_parser

    # Registers a request matcher for later use.
    #
    # @example
    #  VCR.configure do |c|
    #    c.register_request_matcher :port do |request_1, request_2|
    #      URI(request_1.uri).port == URI(request_2.uri).port
    #    end
    #  end
    #
    #  VCR.use_cassette("my_cassette", :match_requests_on => [:method, :host, :port]) do
    #    # ...
    #  end
    #
    # @param name [Symbol] the name of the request matcher
    # @yield the request matcher
    # @yieldparam request_1 [VCR::Request] One request
    # @yieldparam request_2 [VCR::Request] The other request
    # @yieldreturn [Boolean] whether or not these two requests should be considered
    #  equivalent
    def register_request_matcher(name : Symbol, &block : Request, Request -> Bool)
      VCR.request_matchers.register(name, &block)
    end

    # Sets up a {#before_record} and a {#before_playback} hook that will
    # insert a placeholder string in the cassette in place of another string.
    # You can use this as a generic way to interpolate a variable into the
    # cassette for a unique string. It's particularly useful for unique
    # sensitive strings like API keys and passwords.
    #
    # @example
    #   VCR.configure do |c|
    #     # Put "<GITHUB_API_KEY>" in place of the actual API key in
    #     # our cassettes so we don't have to commit to source control.
    #     c.filter_sensitive_data('<GITHUB_API_KEY>') { GithubClient.api_key }
    #
    #     # Put a "<USER_ID>" placeholder variable in our cassettes tagged with
    #     # :user_cassette since it can be different for different test runs.
    #     c.define_cassette_placeholder('<USER_ID>', :user_cassette) { User.last.id }
    #   end
    #
    # @param placeholder [String] The placeholder string.
    # @param tag [Symbol] Set this to apply this only to cassettes
    #  with a matching tag; otherwise it will apply to every cassette.
    # @yield block that determines what string to replace
    # @yieldreturn the string to replace
    def define_cassette_placeholder(placeholder : String, tag : Symbol? = nil, &block : -> String)
      before_record(tag) do |interaction|
        orig_text = block.call
        log "before_record: replacing #{orig_text.inspect} with #{placeholder.inspect}"
        interaction.filter!(orig_text, placeholder)
      end

      before_playback(tag) do |interaction|
        orig_text = block.call
        log "before_playback: replacing #{placeholder.inspect} with #{orig_text.inspect}"
        interaction.filter!(placeholder, orig_text)
      end
    end

    # Variant that takes a static string value instead of a block
    def define_cassette_placeholder(placeholder : String, sensitive_value : String, tag : Symbol? = nil)
      define_cassette_placeholder(placeholder, tag) { sensitive_value }
    end

    # Filters sensitive data from cassettes by replacing `sensitive_value` with `placeholder`.
    # This is an alias for define_cassette_placeholder for Ruby VCR compatibility.
    #
    # @example
    #   VCR.configure do |c|
    #     c.filter_sensitive_data('<API_KEY>') { ENV["API_KEY"] }
    #     c.filter_sensitive_data('<PASSWORD>') { "my_secret_password" }
    #   end
    def filter_sensitive_data(placeholder : String, tag : Symbol? = nil, &block : -> String)
      define_cassette_placeholder(placeholder, tag, &block)
    end

    # Filters sensitive data using a static value
    def filter_sensitive_data(placeholder : String, sensitive_value : String, tag : Symbol? = nil)
      define_cassette_placeholder(placeholder, sensitive_value, tag)
    end

    # Gets the registry of cassette serializers. Use it to register a custom serializer.
    #
    # @example
    #   VCR.configure do |c|
    #     c.cassette_serializers[:my_custom_serializer] = my_custom_serializer
    #   end
    #
    # @return [VCR::Cassette::Serializers] the cassette serializer registry object.
    # @note Custom serializers must implement the following interface:
    #
    #   * `file_extension      # => String`
    #   * `serialize(Hash)     # => String`
    #   * `deserialize(String) # => Hash`
    def cassette_serializers
      VCR.cassette_serializers
    end

    # Gets the registry of cassette persisters. Use it to register a custom persister.
    #
    # @example
    #   VCR.configure do |c|
    #     c.cassette_persisters[:my_custom_persister] = my_custom_persister
    #   end
    #
    # @return [VCR::Cassette::Persisters] the cassette persister registry object.
    # @note Custom persisters must implement the following interface:
    #
    #   * `persister[storage_key]`           # returns previously persisted content
    #   * `persister[storage_key] = content` # persists given content
    def cassette_persisters
      VCR.cassette_persisters
    end

    # Adds a callback that will be called before the recorded HTTP interactions
    # are serialized and written to disk.
    #
    # @example
    #  VCR.configure do |c|
    #    # Don't record transient 5xx errors
    #    c.before_record do |interaction|
    #      interaction.ignore! if interaction.response.status.code >= 500
    #    end
    #
    #    # Modify the response body for cassettes tagged with :twilio
    #    c.before_record(:twilio) do |interaction|
    #      interaction.response.body.downcase!
    #    end
    #  end
    #
    # @param tag [(optional) Symbol] Used to apply this hook to only cassettes that match
    #  the given tag.
    # @yield the callback
    # @yieldparam interaction [VCR::HTTPInteraction::HookAware] The interaction that will be
    #  serialized and written to disk.
    # @yieldparam cassette [(optional) VCR::Cassette] The current cassette.
    # @see #before_playback
    define_hook :before_record

    # Adds a callback that will be called before a previously recorded
    # HTTP interaction is loaded for playback.
    #
    # @example
    #  VCR.configure do |c|
    #    # Don't playback transient 5xx errors
    #    c.before_playback do |interaction|
    #      interaction.ignore! if interaction.response.status.code >= 500
    #    end
    #
    #    # Change a response header for playback
    #    c.before_playback(:twilio) do |interaction|
    #      interaction.response.headers['X-Foo-Bar'] = 'Bazz'
    #    end
    #  end
    #
    # @param tag [(optional) Symbol] Used to apply this hook to only cassettes that match
    #  the given tag.
    # @yield the callback
    # @yieldparam interaction [VCR::HTTPInteraction::HookAware] The interaction that is being
    #  loaded.
    # @yieldparam cassette [(optional) VCR::Cassette] The current cassette.
    # @see #before_record
    define_hook :before_playback

    # Adds a callback that will be called with each HTTP request before it is made.
    #
    # @example
    #  VCR.configure do |c|
    #    c.before_http_request(:real?) do |request|
    #      puts "Request: #{request.method} #{request.uri}"
    #    end
    #  end
    #
    # @param filters [optional splat of #to_proc] one or more filters to apply.
    #   The objects provided will be converted to procs using `#to_proc`. If provided,
    #   the callback will only be invoked if these procs all return `true`.
    # @yield the callback
    # @yieldparam request [VCR::Request::Typed] the request that is being made
    # @see #after_http_request
    # @see #around_http_request
    define_hook :before_http_request

    define_hook :after_http_request, prepend: true

    # Adds a callback that will be called with each HTTP request after it is complete.
    #
    # @example
    #  VCR.configure do |c|
    #    c.after_http_request(:ignored?) do |request, response|
    #      puts "Request: #{request.method} #{request.uri}"
    #      puts "Response: #{response.status.code}"
    #    end
    #  end
    #
    # @param filters [optional splat of #to_proc] one or more filters to apply.
    #   The objects provided will be converted to procs using `#to_proc`. If provided,
    #   the callback will only be invoked if these procs all return `true`.
    # @yield the callback
    # @yieldparam request [VCR::Request::Typed] the request that is being made
    # @yieldparam response [VCR::Response] the response from the request
    # @see #before_http_request
    # @see #around_http_request
    def after_http_request(*filters)
      super *filters.map { |f| request_filter_from(f) }
    end

    # Adds a callback that will be executed around each HTTP request.
    #
    # @example
    #  VCR.configure do |c|
    #    c.around_http_request(lambda {|r| r.uri =~ /api.geocoder.com/}) do |request|
    #      # extract an address like "1700 E Pine St, Seattle, WA"
    #      # from a query like "address=1700+E+Pine+St%2C+Seattle%2C+WA"
    #      address = CGI.unescape(URI(request.uri).query.split('=').last)
    #      VCR.use_cassette("geocoding/#{address}", &request)
    #    end
    #  end
    #
    # @yield the callback
    # @yieldparam request [VCR::Request::FiberAware] the request that is being made
    # @raise [VCR::Errors::NotSupportedError] if the fiber library cannot be loaded.
    # @param filters [optional splat of #to_proc] one or more filters to apply.
    #   The objects provided will be converted to procs using `#to_proc`. If provided,
    #   the callback will only be invoked if these procs all return `true`.
    # @note This method can only be used on ruby interpreters that support
    #  fibers (i.e. 1.9+). On 1.8 you can use separate `before_http_request` and
    #  `after_http_request` hooks.
    # @note You _must_ call `request.proceed` or pass the request as a proc on to a
    #  method that yields to a block (i.e. `some_method(&request)`).
    # @see #before_http_request
    # @see #after_http_request
    def around_http_request(*filters, &block)
      unless VCR.fibers_available?
        raise Errors::NotSupportedError
          .new "VCR::Configuration#around_http_request requires fibers, " +
               "which are not available on your ruby intepreter."
      end
      fibers = {} of String => String
      fiber_errors = {} of String => String
      hook_allowed = false
      hook_declaration = caller.first
      before_http_request(*filters) do |request|
        hook_allowed = true
        start_new_fiber_for(request, fibers, fiber_errors, hook_declaration, block)
      end

      after_http_request(-> { hook_allowed }) do |request, response|
        fiber = fibers.delete(Thread.current)
        resume_fiber(fiber, fiber_errors, response, hook_declaration)
      end
    end

    # Configures RSpec to use a VCR cassette for any example
    # tagged with `:vcr`.
    def configure_rspec_metadata!
      unless @rspec_metadata_configured
        VCR::RSpec::Metadata.configure!
        @rspec_metadata_configured = true
      end
    end

    getter debug_logger

    # @private (documented above)
    def debug_logger=(value)
      @debug_logger = value

      if value
        @logger = Logger.new(value)
      else
        @logger = Logger::Null
      end
    end

    getter logger

    # Sets a callback that determines whether or not to base64 encode
    # the bytes of a request or response body during serialization in
    # order to preserve them exactly.
    #
    # @example
    #   VCR.configure do |c|
    #     c.preserve_exact_body_bytes do |http_message|
    #       http_message.body.encoding == Encoding::BINARY ||
    #       !http_message.body.valid_encoding?
    #     end
    #   end
    #
    # @yield the callback
    # @yieldparam http_message [#body, #headers] the `VCR::Request` or `VCR::Response` object being serialized
    # @yieldparam cassette [VCR::Cassette] the cassette the http message belongs to
    # @yieldreturn [Boolean] whether or not to preserve the exact bytes for the body of the given HTTP message
    # @return [void]
    # @see #preserve_exact_body_bytes_for?
    # @note This is usually only necessary when the HTTP server returns a response
    #  with a non-standard encoding or with a body containing invalid bytes for the given
    #  encoding. Note that when you set this, and the block returns true, you sacrifice
    #  the human readability of the data in the cassette.
    def preserve_exact_body_bytes(&block : Request | Response, Cassette? -> Bool)
      hooks = @preserve_exact_body_bytes_hooks
      if hooks.nil?
        hooks = [] of Proc(Request | Response, Cassette?, Bool)
        @preserve_exact_body_bytes_hooks = hooks
      end
      hooks << block
    end

    # @return [Boolean] whether or not the body of the given HTTP message should
    #  be base64 encoded during serialization in order to preserve the bytes exactly.
    # @param http_message [#body, #headers] the `VCR::Request` or `VCR::Response` object being serialized
    # @see #preserve_exact_body_bytes
    def preserve_exact_body_bytes_for?(http_message : Request | Response) : Bool
      hooks = @preserve_exact_body_bytes_hooks
      return false if hooks.nil?
      hooks.any?(&.call(http_message, VCR.current_cassette))
    end

    def initialize
      @allow_http_connections_when_no_cassette = false
      @rspec_metadata_configured = false
      @debug_logger = nil
      @logger = Logger::Null
      @uri_parser = URI
      @query_parser = nil
      @default_cassette_options = CassetteOptions.new
      @default_cassette_options[:record] = :once
      @default_cassette_options[:record_on_error] = true
      @default_cassette_options[:match_requests_on] = [:method, :uri]
      @default_cassette_options[:allow_unused_http_interactions] = true
      @default_cassette_options[:drop_unused_requests] = false
      @default_cassette_options[:serialize_with] = :yaml
      @default_cassette_options[:persist_with] = :file_system

      register_built_in_hooks
    end

    private def load_library_hook(hook)
      # In Crystal, library hooks are loaded at compile time via requires.
      # This method is kept for API compatibility but doesn't dynamically load.
      # Note: Crystal's HTTP::Client hook is loaded automatically.
      nil
    end

    private def resume_fiber(fiber, fiber_errors, response, hook_declaration)
      # Crystal's fiber handling - simplified from Ruby version
      # Note: around_http_request is complex and may need further work for full compatibility
    end

    private def create_fiber_for(fiber_errors, hook_declaration, proc)
      # Crystal's fiber handling - simplified from Ruby version
      # Note: around_http_request is complex and may need further work for full compatibility
      nil
    end

    private def start_new_fiber_for(request, fibers, fiber_errors, hook_declaration, proc)
      # Crystal's fiber handling - simplified from Ruby version
      # Note: around_http_request is complex and may need further work for full compatibility
    end

    private def tag_filter_from(tag)
      return -> { true } unless tag
      ->(interaction : HTTPInteraction::HookAware, cassette : Cassette?) {
        if c = cassette
          if tags = c.tags
            tags.includes?(tag)
          else
            false
          end
        else
          false
        end
      }
    end

    private def request_filter_from(object)
      return object unless object.is_a?(Symbol)
      ->(arg : Request::Typed) {
        case object
        when :real?       then arg.real?
        when :stubbed?    then arg.stubbed?
        when :ignored?    then arg.ignored?
        when :recordable? then arg.recordable?
        else                   false
        end
      }
    end

    private def register_built_in_hooks
      before_playback(:recompress_response) do |interaction|
        interaction.response.recompress if interaction.response.vcr_decompressed?
      end

      before_playback(:update_content_length_header) do |interaction|
        interaction.response.update_content_length_header
      end

      before_record(:decode_compressed_response) do |interaction|
        interaction.response.decompress if interaction.response.compressed?
      end

      preserve_exact_body_bytes do |http_message, cassette|
        if c = cassette
          if tags = c.tags
            tags.includes?(:preserve_exact_body_bytes)
          else
            false
          end
        else
          false
        end
      end
    end

    private def log_prefix
      "[VCR::Configuration] "
    end

    # @private
    define_hook :after_library_hooks_loaded
  end
end
