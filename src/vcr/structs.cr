require "time"
require "compress/gzip"
require "base64"

module VCR
  # The request of an {HTTPInteraction}.
  #
  # @attr [String] method the HTTP method (i.e. :head, :options, :get, :post, :put, :patch or :delete)
  # @attr [String] uri the request URI
  # @attr [String, nil] body the request body
  # @attr [Hash{String => Array<String>}] headers the request headers
  class Request
    property method : String
    property uri : String
    property body : String?
    property headers : Hash(String, Array(String))

    def initialize(@method : String, @uri : String, @body : String?, @headers : Hash(String, Array(String)))
      normalize_headers
    end

    # Builds a serializable hash from the request data.
    #
    # @return [Hash] hash that represents this request and can be easily
    #  serialized.
    # @see Request.from_hash
    def to_hash
      {
        "method"  => method.to_s,
        "uri"     => uri,
        "body"    => serializable_body,
        "headers" => headers,
      }
    end

    # Constructs a new instance from a hash.
    #
    # @param [Hash] hash the hash to use to construct the instance.
    # @return [Request] the request
    def self.from_hash(hash)
      # Handle YAML::Any wrapper
      h = normalize_hash(hash)
      method_val = h["method"]?.try(&.to_s) || "get"
      uri_val = h["uri"]?.try(&.to_s) || ""
      body_val = body_from(h["body"]?)
      headers_val = headers_from(h["headers"]?)
      new(method_val, uri_val, body_val, headers_val)
    end

    # @private
    def self.normalize_hash(hash)
      case hash
      when YAML::Any
        hash.as_h? || {} of YAML::Any => YAML::Any
      else
        hash
      end
    end

    # Parses the URI using the configured `uri_parser`.
    #
    # @return [#schema, #host, #port, #path, #query] A parsed URI object.
    def parsed_uri
      URI.parse(uri)
    end

    private def normalize_headers
      return unless @headers
      new_headers = {} of String => Array(String)
      @headers.each do |k, v|
        new_headers[k] = v.is_a?(Array) ? v : [v.to_s]
      end
      @headers = new_headers
    end

    private def serializable_body
      return {"string" => ""} if body.nil?
      body_str = body.to_s

      if VCR.configuration.preserve_exact_body_bytes_for?(self) || !body_str.valid_encoding?
        base64_encoded = Base64.strict_encode(body_str)
        {"base64_string" => base64_encoded}
      else
        {"string" => body_str}
      end
    end

    def self.body_from(hash_or_string) : String?
      return nil if hash_or_string.nil?

      # Handle YAML::Any wrapper
      case hash_or_string
      when YAML::Any
        if h = hash_or_string.as_h?
          if h["base64_string"]?
            Base64.decode_string(h["base64_string"].to_s)
          else
            h["string"]?.try(&.to_s)
          end
        else
          hash_or_string.as_s? || hash_or_string.to_s
        end
      when Hash
        if hash_or_string.has_key?("base64_string")
          Base64.decode_string(hash_or_string["base64_string"].to_s)
        else
          hash_or_string["string"]?.try(&.to_s)
        end
      else
        hash_or_string.to_s
      end
    end

    def self.headers_from(headers_hash) : Hash(String, Array(String))
      result = {} of String => Array(String)
      return result if headers_hash.nil?

      # Handle YAML::Any wrapper
      h = case headers_hash
          when YAML::Any
            headers_hash.as_h? || {} of YAML::Any => YAML::Any
          when Hash
            headers_hash
          else
            return result
          end

      h.each do |k, v|
        key = k.to_s
        result[key] = case v
                      when YAML::Any
                        if arr = v.as_a?
                          arr.map(&.to_s)
                        elsif v.raw.nil?
                          [] of String
                        else
                          [v.to_s]
                        end
                      when Array
                        v.map(&.to_s)
                      when Nil
                        [] of String
                      else
                        [v.to_s]
                      end
      end
      result
    end

    # Decorates a {Request} with its current type.
    class Typed
      getter type : Symbol
      getter request : Request

      # @param [Request] request the request
      # @param [Symbol] type the type. Should be one of `:ignored`, `:stubbed`, `:recordable` or `:unhandled`.
      def initialize(@request : Request, @type : Symbol)
      end

      forward_missing_to @request

      # @return [Boolean] whether or not this request is being ignored
      def ignored?
        type == :ignored
      end

      # @return [Boolean] whether or not this request is being stubbed by VCR
      # @see #externally_stubbed?
      # @see #stubbed?
      def stubbed_by_vcr?
        type == :stubbed_by_vcr
      end

      # @return [Boolean] whether or not this request is being stubbed by an
      #  external library (such as WebMock).
      # @see #stubbed_by_vcr?
      # @see #stubbed?
      def externally_stubbed?
        type == :externally_stubbed
      end

      # @return [Boolean] whether or not this request will be recorded.
      def recordable?
        type == :recordable
      end

      # @return [Boolean] whether or not VCR knows how to handle this request.
      def unhandled?
        type == :unhandled
      end

      # @return [Boolean] whether or not this request will be made for real.
      # @note VCR allows `:ignored` and `:recordable` requests to be made for real.
      def real?
        ignored? || recordable?
      end

      # @return [Boolean] whether or not this request will be stubbed.
      #  It may be stubbed by an external library or by VCR.
      # @see #stubbed_by_vcr?
      # @see #externally_stubbed?
      def stubbed?
        stubbed_by_vcr? || externally_stubbed?
      end
    end

    # Provides fiber-awareness for the {VCR::Configuration#around_http_request} hook.
    class FiberAware
      getter request : Request

      def initialize(@request : Request)
      end

      forward_missing_to @request

      # Yields the fiber so the request can proceed.
      #
      # @return [VCR::Response] the response from the request
      def proceed
        Fiber.yield
      end

      # Builds a proc that allows the request to proceed when called.
      # This allows you to treat the request as a proc and pass it on
      # to a method that yields (at which point the request will proceed).
      #
      # @return [Proc] the proc
      def to_proc
        -> { proceed }
      end
    end
  end

  # The response of an {HTTPInteraction}.
  #
  # @attr [ResponseStatus] status the status of the response
  # @attr [Hash{String => Array<String>}] headers the response headers
  # @attr [String] body the response body
  # @attr [nil, String] http_version the HTTP version
  # @attr [Hash] adapter_metadata Additional metadata used by a specific VCR adapter.
  class Response
    property status : ResponseStatus
    property headers : Hash(String, Array(String))
    property body : String?
    property http_version : String?
    property adapter_metadata : Hash(String, String)

    def initialize(@status : ResponseStatus, @headers : Hash(String, Array(String)), @body : String?, @http_version : String? = nil, @adapter_metadata : Hash(String, String) = {} of String => String)
      normalize_headers
    end

    # Builds a serializable hash from the response data.
    #
    # @return [Hash] hash that represents this response
    #  and can be easily serialized.
    # @see Response.from_hash
    def to_hash
      hash = {
        "status"  => status.to_hash,
        "headers" => headers,
        "body"    => serializable_body,
      } of String => Hash(String, String) | Hash(String, Array(String)) | Hash(String, Int32 | String?) | String?
      hash["http_version"] = http_version if http_version
      hash["adapter_metadata"] = adapter_metadata unless adapter_metadata.empty?
      hash
    end

    # Constructs a new instance from a hash.
    #
    # @param [Hash] hash the hash to use to construct the instance.
    # @return [Response] the response
    def self.from_hash(hash)
      # Handle YAML::Any wrapper
      h = Request.normalize_hash(hash)
      status_hash = h["status"]?
      status = case status_hash
               when YAML::Any
                 ResponseStatus.from_hash(status_hash)
               when Hash
                 ResponseStatus.from_hash(status_hash)
               else
                 ResponseStatus.new(0, nil)
               end
      headers = Request.headers_from(h["headers"]?)
      body = Request.body_from(h["body"]?)
      http_version = h["http_version"]?.try(&.to_s)
      adapter_metadata = {} of String => String
      if am = h["adapter_metadata"]?
        am_hash = case am
                  when YAML::Any
                    am.as_h? || {} of YAML::Any => YAML::Any
                  when Hash
                    am
                  else
                    {} of String => String
                  end
        am_hash.each { |k, v| adapter_metadata[k.to_s] = v.to_s }
      end
      new(status, headers, body, http_version, adapter_metadata)
    end

    # Updates the Content-Length response header so that it is
    # accurate for the response body.
    def update_content_length_header
      if key = header_key("Content-Length")
        b = body
        headers[key] = [b ? b.bytesize.to_s : "0"]
      end
    end

    # The type of encoding.
    #
    # @return [String] encoding type
    def content_encoding
      if key = header_key("Content-Encoding")
        headers[key]?.try(&.first?)
      end
    end

    # Checks if the type of encoding is one of "gzip" or "deflate".
    def compressed?
      enc = content_encoding
      enc == "gzip" || enc == "deflate"
    end

    # Checks if VCR decompressed the response body
    def vcr_decompressed?
      adapter_metadata["vcr_decompressed"]?
    end

    # Decodes the compressed body and deletes evidence that it was ever compressed.
    #
    # @return self
    # @raise [VCR::Errors::UnknownContentEncodingError] if the content encoding
    #  is not a known encoding.
    def decompress
      b = body
      return self if b.nil?
      enc = content_encoding
      case enc
      when "gzip"
        io = IO::Memory.new(b)
        reader = Compress::Gzip::Reader.new(io)
        self.body = reader.gets_to_end
        reader.close
        adapter_metadata["vcr_decompressed"] = "gzip"
        delete_header("Content-Encoding")
        update_content_length_header
      when "deflate"
        io = IO::Memory.new(b)
        reader = Compress::Zlib::Reader.new(io)
        self.body = reader.gets_to_end
        reader.close
        adapter_metadata["vcr_decompressed"] = "deflate"
        delete_header("Content-Encoding")
        update_content_length_header
      when "identity", nil
        # No decompression needed
      else
        raise Errors::UnknownContentEncodingError.new("unknown content encoding: #{enc}")
      end
      self
    end

    # Recompresses the decompressed body according to adapter metadata.
    #
    # @raise [VCR::Errors::UnknownContentEncodingError] if the content encoding
    #  stored in the adapter metadata is unknown
    def recompress
      type = adapter_metadata["vcr_decompressed"]?
      b = body
      return if type.nil? || b.nil?

      case type
      when "gzip"
        io = IO::Memory.new
        writer = Compress::Gzip::Writer.new(io)
        writer.write(b.to_slice)
        writer.close
        self.body = io.to_s
        update_content_length_header
        set_header("Content-Encoding", type)
      when "deflate"
        io = IO::Memory.new
        writer = Compress::Zlib::Writer.new(io)
        writer.write(b.to_slice)
        writer.close
        self.body = io.to_s
        update_content_length_header
        set_header("Content-Encoding", type)
      when "identity", nil
        # No recompression needed
      else
        raise Errors::UnknownContentEncodingError.new("unknown content encoding: #{type}")
      end
    end

    private def normalize_headers
      return unless @headers
      new_headers = {} of String => Array(String)
      @headers.each do |k, v|
        new_headers[k] = v.is_a?(Array) ? v : [v.to_s]
      end
      @headers = new_headers
    end

    private def serializable_body
      return {"string" => ""} if body.nil?
      body_str = body.to_s

      if VCR.configuration.preserve_exact_body_bytes_for?(self) || !body_str.valid_encoding?
        base64_encoded = Base64.strict_encode(body_str)
        {"base64_string" => base64_encoded}
      else
        {"string" => body_str}
      end
    end

    private def header_key(key : String) : String?
      headers.keys.find { |k| k.downcase == key.downcase }
    end

    private def get_header(key : String) : Array(String)?
      if k = header_key(key)
        headers[k]?
      end
    end

    private def set_header(key : String, value : String)
      if k = header_key(key)
        headers[k] = [value]
      else
        headers[key] = [value]
      end
    end

    private def delete_header(key : String)
      if k = header_key(key)
        headers.delete(k)
      end
    end
  end

  # The response status of an {HTTPInteraction}.
  #
  # @attr [Integer] code the HTTP status code
  # @attr [String] message the HTTP status message (e.g. "OK" for a status of 200)
  class ResponseStatus
    property code : Int32
    property message : String?

    def initialize(@code : Int32, @message : String?)
    end

    # Builds a serializable hash from the response status data.
    #
    # @return [Hash] hash that represents this response status
    #  and can be easily serialized.
    # @see ResponseStatus.from_hash
    def to_hash
      {
        "code"    => code,
        "message" => message,
      }
    end

    # Constructs a new instance from a hash.
    #
    # @param [Hash] hash the hash to use to construct the instance.
    # @return [ResponseStatus] the response status
    def self.from_hash(hash)
      # Handle YAML::Any wrapper
      h = Request.normalize_hash(hash)
      code = h["code"]?.try(&.to_s.to_i) || 0
      message = h["message"]?.try(&.to_s)
      new(code, message)
    end
  end

  # Represents a single interaction over HTTP, containing a request and a response.
  #
  # @attr [Request] request the request
  # @attr [Response] response the response
  # @attr [Time] recorded_at when this HTTP interaction was recorded
  class HTTPInteraction
    property request : Request
    property response : Response
    property recorded_at : Time
    @hook_aware_cached : HookAware?

    def initialize(@request : Request, @response : Response, @recorded_at : Time = Time.utc)
      @hook_aware_cached = nil
    end

    # Builds a serializable hash from the HTTP interaction data.
    #
    # @return [Hash] hash that represents this HTTP interaction
    #  and can be easily serialized.
    # @see HTTPInteraction.from_hash
    def to_hash
      {
        "request"     => request.to_hash,
        "response"    => response.to_hash,
        "recorded_at" => recorded_at.to_rfc2822,
      }
    end

    # Constructs a new instance from a hash.
    #
    # @param [Hash] hash the hash to use to construct the instance.
    # @return [HTTPInteraction] the HTTP interaction
    def self.from_hash(hash)
      # Handle YAML::Any wrapper
      h = Request.normalize_hash(hash)
      request_hash = h["request"]?
      response_hash = h["response"]?
      recorded_at_str = h["recorded_at"]?.try(&.to_s)

      request = case request_hash
                when YAML::Any, Hash
                  Request.from_hash(request_hash)
                else
                  Request.new("get", "", nil, {} of String => Array(String))
                end

      response = case response_hash
                 when YAML::Any, Hash
                   Response.from_hash(response_hash)
                 else
                   Response.new(ResponseStatus.new(0, nil), {} of String => Array(String), nil)
                 end

      recorded_at = if recorded_at_str
                      begin
                        Time.parse_rfc2822(recorded_at_str)
                      rescue
                        Time.utc
                      end
                    else
                      Time.utc
                    end

      new(request, response, recorded_at)
    end

    # @return [HookAware] an instance with additional capabilities
    #  suitable for use in `before_record` and `before_playback` hooks.
    #  The HookAware instance is cached so that state like `ignored?` persists.
    def hook_aware : HookAware
      @hook_aware_cached ||= HookAware.new(self)
    end

    # Decorates an {HTTPInteraction} with additional methods useful
    # for a `before_record` or `before_playback` hook.
    class HookAware
      getter interaction : HTTPInteraction
      @ignored : Bool = false

      def initialize(@interaction : HTTPInteraction)
      end

      forward_missing_to @interaction

      # Flags the HTTP interaction so that VCR ignores it. This is useful in
      # a {VCR::Configuration#before_record} or {VCR::Configuration#before_playback}
      # hook so that VCR does not record or play it back.
      # @see #ignored?
      def ignore!
        @ignored = true
      end

      # @return [Boolean] whether or not this HTTP interaction should be ignored.
      # @see #ignore!
      def ignored?
        @ignored
      end

      # Replaces a string in any part of the HTTP interaction (headers, request body,
      # response body, etc) with the given replacement text.
      #
      # @param [#to_s] text the text to replace
      # @param [#to_s] replacement_text the text to put in its place
      def filter!(text : String, replacement_text : String)
        return self if text.empty? || replacement_text.empty?

        # Filter request body
        if req_body = interaction.request.body
          interaction.request.body = req_body.gsub(text, replacement_text)
        end

        # Filter response body
        if resp_body = interaction.response.body
          interaction.response.body = resp_body.gsub(text, replacement_text)
        end

        # Filter request URI
        interaction.request.uri = interaction.request.uri.gsub(text, replacement_text)

        # Filter headers
        filter_headers!(interaction.request.headers, text, replacement_text)
        filter_headers!(interaction.response.headers, text, replacement_text)

        self
      end

      private def filter_headers!(headers : Hash(String, Array(String)), text : String, replacement_text : String)
        headers.each do |key, values|
          headers[key] = values.map(&.gsub(text, replacement_text))
        end
      end
    end
  end
end
