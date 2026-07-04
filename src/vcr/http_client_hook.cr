require "http/client"
require "http/request"
require "digest/md5"
require "json"

# Extension to HTTP::Request for VCR serialization
class ::HTTP::Request
  def to_json
    {
      method:       method,
      host:         hostname,
      resource:     resource,
      headers:      headers.to_h,
      body:         body_string,
      query_params: query_params.to_h,
    }.to_json
  end

  def body_string
    if !body.nil? && body.is_a?(::File)
      body.as(::File).gets_to_end.tap do |_|
        body.as(::File).rewind
      end
    else
      body.to_s
    end
  end
end

# HTTP::Client extension for VCR request interception
class ::HTTP::Client
  {% if compare_versions(Crystal::VERSION, "1.6.0-0") >= 0 %}
    private def _vcr_original_exec(request, implicit_compression = false)
      decompress = send_request(request)
      ::HTTP::Client::Response.from_io?(io, ignore_body: request.ignore_body?, decompress: implicit_compression)
    end

    private def exec_internal_single(request, implicit_compression = false)
      cassette = VCR.current_cassette
      if cassette.nil?
        _vcr_original_exec(request, implicit_compression: implicit_compression)
      else
        _vcr_handle_request(request, cassette, implicit_compression)
      end
    end

    # block / streaming form. `client.get(...) { |resp| resp.body_io ... }` goes
    # through here, and stdlib routes it to a DIFFERENT internal than the
    # buffered form above, so it needs its own interception or streaming calls
    # (SSE, chunked downloads) silently bypass the cassette.
    private def _vcr_stream_real(request, ignore_io_error, implicit_compression, &block : ::HTTP::Client::Response? -> _)
      begin
        send_request(request)
      rescue ex : ::IO::Error
        return yield nil if ignore_io_error && !@io.nil?
        raise ex
      end
      ::HTTP::Client::Response.from_io?(io, ignore_body: request.ignore_body?, decompress: implicit_compression) do |response|
        yield response
      end
    end

    private def exec_internal_single(request, ignore_io_error = false, implicit_compression = false, &block : ::HTTP::Client::Response? -> _)
      cassette = VCR.current_cassette
      if cassette.nil?
        return _vcr_stream_real(request, ignore_io_error, implicit_compression) { |r| yield r }
      end

      vcr_request = _build_vcr_request(request)
      if VCR.request_ignorer.ignore?(vcr_request)
        return _vcr_stream_real(request, ignore_io_error, implicit_compression) { |r| yield r }
      end

      if response_data = cassette.http_interactions.response_for(vcr_request)
        # replay: hand the block a response whose body_io is an in-memory copy
        # of the recorded body, so line-by-line streaming reads work.
        yield _build_streaming_http_response(response_data)
      elsif cassette.recording?
        # record: run for real, capture the streamed body, then re-yield a
        # replayable copy so the caller still sees a working stream.
        _vcr_stream_real(request, ignore_io_error, implicit_compression) do |response|
          if response
            vcr_response = _build_vcr_response_streaming(response)
            interaction = VCR::HTTPInteraction.new(vcr_request, vcr_response, Time.utc)
            cassette.record_http_interaction(interaction)
            # re-yield a streaming copy so the caller (which reads body_io) still
            # gets a working stream after we drained the original to record it.
            yield _build_streaming_http_response(vcr_response)
          else
            yield nil
          end
        end
      else
        raise VCR::Errors::UnhandledHTTPRequestError.new(vcr_request)
      end
    end
  {% else %}
    private def _vcr_original_exec(request)
      decompress = send_request(request)
      ::HTTP::Client::Response.from_io?(io, ignore_body: request.ignore_body?, decompress: decompress)
    end

    private def exec_internal_single(request)
      cassette = VCR.current_cassette
      if cassette.nil?
        _vcr_original_exec(request)
      else
        _vcr_handle_request(request, cassette, false)
      end
    end
  {% end %}

  private def _vcr_handle_request(request, cassette, implicit_compression)
    # Build VCR request from HTTP request
    vcr_request = _build_vcr_request(request)

    # Check if request should be ignored
    if VCR.request_ignorer.ignore?(vcr_request)
      {% if compare_versions(Crystal::VERSION, "1.6.0-0") >= 0 %}
        return _vcr_original_exec(request, implicit_compression: implicit_compression)
      {% else %}
        return _vcr_original_exec(request)
      {% end %}
    end

    # Try to find a matching recorded response
    if response_data = cassette.http_interactions.response_for(vcr_request)
      # Return the recorded response
      _build_http_response(response_data)
    elsif cassette.recording?
      # Make real request and record it
      {% if compare_versions(Crystal::VERSION, "1.6.0-0") >= 0 %}
        response = _vcr_original_exec(request, implicit_compression: implicit_compression)
        if response
          vcr_response = _build_vcr_response(response)
          interaction = VCR::HTTPInteraction.new(vcr_request, vcr_response, Time.utc)
          cassette.record_http_interaction(interaction)
        end
        response
      {% else %}
        response = _vcr_original_exec(request)
        if response
          vcr_response = _build_vcr_response(response)
          interaction = VCR::HTTPInteraction.new(vcr_request, vcr_response, Time.utc)
          cassette.record_http_interaction(interaction)
        end
        response
      {% end %}
    else
      # No matching interaction and not recording - raise error
      raise VCR::Errors::UnhandledHTTPRequestError.new(vcr_request)
    end
  end

  private def _build_vcr_request(request : ::HTTP::Request) : VCR::Request
    method = request.method.to_s.downcase
    uri = "#{tls? ? "https" : "http"}://#{@host}:#{@port}#{request.resource}"
    body = request.body_string
    headers = {} of String => Array(String)
    request.headers.each do |key, values|
      headers[key] = values.is_a?(Array) ? values : [values]
    end
    VCR::Request.new(method, uri, body, headers)
  end

  private def _build_vcr_response(response : ::HTTP::Client::Response) : VCR::Response
    status = VCR::ResponseStatus.new(response.status_code, response.status_message)
    headers = {} of String => Array(String)
    response.headers.each do |key, values|
      headers[key] = values.is_a?(Array) ? values : [values]
    end
    body = response.body
    http_version = response.version
    VCR::Response.new(status, headers, body, http_version, {} of String => String)
  end

  # like _build_vcr_response but drains a streaming response's body_io (the
  # buffered `.body` is empty for block-form responses).
  private def _build_vcr_response_streaming(response : ::HTTP::Client::Response) : VCR::Response
    status = VCR::ResponseStatus.new(response.status_code, response.status_message)
    headers = {} of String => Array(String)
    response.headers.each do |key, values|
      headers[key] = values.is_a?(Array) ? values : [values]
    end
    body = response.body_io?.try(&.gets_to_end) || response.body
    VCR::Response.new(status, headers, body, response.version, {} of String => String)
  end

  # replay for the streaming/block form: a Response whose body_io is a live
  # IO::Memory, so callers reading `response.body_io` line by line (SSE) work.
  private def _build_streaming_http_response(vcr_response : VCR::Response) : ::HTTP::Client::Response
    headers = ::HTTP::Headers.new
    vcr_response.headers.each do |key, values|
      next if key.downcase == "transfer-encoding"
      next if key.downcase == "content-length"
      values.each { |value| headers.add(key, value) }
    end
    body = vcr_response.body || ""
    ::HTTP::Client::Response.new(
      status_code: vcr_response.status.code,
      body_io: ::IO::Memory.new(body),
      headers: headers,
      status_message: vcr_response.status.message,
    )
  end

  private def _build_http_response(vcr_response : VCR::Response) : ::HTTP::Client::Response
    io = ::IO::Memory.new
    version = vcr_response.http_version || "HTTP/1.1"
    # strip "HTTP/" prefix if present to avoid duplication
    version = version.sub(/^HTTP\//, "")
    io << "HTTP/#{version} #{vcr_response.status.code} #{vcr_response.status.message}\r\n"

    body = vcr_response.body
    body_size = body.try(&.bytesize) || 0

    vcr_response.headers.each do |key, values|
      # skip Transfer-Encoding since body is already decoded
      next if key.downcase == "transfer-encoding"
      # update Content-Length to actual body size
      if key.downcase == "content-length"
        io << "Content-Length: #{body_size}\r\n"
      else
        values.each do |value|
          io << "#{key}: #{value}\r\n"
        end
      end
    end
    # ensure Content-Length is present if we have a body
    unless vcr_response.headers.keys.any? { |k| k.downcase == "content-length" }
      io << "Content-Length: #{body_size}\r\n" if body_size > 0
    end
    io << "\r\n"
    io << body if body
    io.rewind
    ::HTTP::Client::Response.from_io(io)
  end
end
