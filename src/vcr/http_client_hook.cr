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
