require "spectator"
require "file_utils"
require "../src/vcr"

SPEC_CASSETTE_DIR = "spec/fixtures/vcr_cassettes"

# Configure VCR for testing
VCR.configure do |c|
  c.cassette_library_dir = SPEC_CASSETTE_DIR
end

# Global cleanup before all specs
Spectator.configure do |config|
  config.before_each do
    # Ensure VCR cassette directory is set correctly
    VCR.configuration.cassette_library_dir = SPEC_CASSETTE_DIR
  end
end

# Helper to clean up test cassettes
def with_clean_cassettes(&)
  FileUtils.rm_rf(SPEC_CASSETTE_DIR)
  FileUtils.mkdir_p(SPEC_CASSETTE_DIR)
  yield
ensure
  FileUtils.rm_rf(SPEC_CASSETTE_DIR)
end

# Helper to create a cassette file with the given YAML content
def create_cassette_file(name : String, content : String)
  path = File.join(SPEC_CASSETTE_DIR, "#{name}.yml")
  dir = File.dirname(path)
  FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
  File.write(path, content)
  path
end

# Helper to build a simple cassette YAML with one interaction
def build_cassette_yaml(
  method : String = "get",
  uri : String = "http://example.com/foo",
  request_body : String = "",
  request_headers : Hash(String, Array(String)) = {} of String => Array(String),
  response_code : Int32 = 200,
  response_message : String = "OK",
  response_body : String = "Hello",
  response_headers : Hash(String, Array(String)) = {"Content-Length" => [response_body.bytesize.to_s]},
) : String
  <<-YAML
  ---
  http_interactions:
  - request:
      method: #{method}
      uri: #{uri}
      body:
        encoding: UTF-8
        string: "#{request_body}"
      headers: #{request_headers.empty? ? "{}" : request_headers.to_yaml.lines[1..].join}
    response:
      status:
        code: #{response_code}
        message: #{response_message}
      headers:
        Content-Length:
        - "#{response_body.bytesize}"
      body:
        encoding: UTF-8
        string: "#{response_body}"
      http_version: "1.1"
    recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
  recorded_with: VCR 2.0.0
  YAML
end

# Helper to build a cassette YAML with multiple interactions
def build_multi_interaction_cassette_yaml(interactions : Array(NamedTuple(
                                            method: String,
                                            uri: String,
                                            request_body: String,
                                            response_body: String))) : String
  yaml = "---\nhttp_interactions:\n"
  interactions.each do |interaction|
    yaml += <<-INTERACTION
    - request:
        method: #{interaction[:method]}
        uri: #{interaction[:uri]}
        body:
          encoding: UTF-8
          string: "#{interaction[:request_body]}"
        headers: {}
      response:
        status:
          code: 200
          message: OK
        headers:
          Content-Length:
          - "#{interaction[:response_body].bytesize}"
        body:
          encoding: UTF-8
          string: "#{interaction[:response_body]}"
        http_version: "1.1"
      recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
    INTERACTION
  end
  yaml += "recorded_with: VCR 2.0.0\n"
  yaml
end

# Standard cassette YAML used in many tests - matches /foo and /bar URIs
URI_MATCHING_CASSETTE_YAML = <<-YAML
---
http_interactions:
- request:
    method: post
    uri: http://example.com/foo
    body:
      encoding: UTF-8
      string: ""
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "12"
    body:
      encoding: UTF-8
      string: foo response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
- request:
    method: post
    uri: http://example.com/bar
    body:
      encoding: UTF-8
      string: ""
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "12"
    body:
      encoding: UTF-8
      string: bar response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
recorded_with: VCR 2.0.0
YAML

# Standard cassette for body matching tests
BODY_MATCHING_CASSETTE_YAML = <<-YAML
---
http_interactions:
- request:
    method: post
    uri: http://example.net/some/long/path
    body:
      encoding: UTF-8
      string: body1
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "14"
    body:
      encoding: UTF-8
      string: body1 response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
- request:
    method: post
    uri: http://example.net/some/long/path
    body:
      encoding: UTF-8
      string: body2
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "14"
    body:
      encoding: UTF-8
      string: body2 response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
recorded_with: VCR 2.0.0
YAML

# Simple cassette with a single GET request
SIMPLE_GET_CASSETTE_YAML = <<-YAML
---
http_interactions:
- request:
    method: get
    uri: http://example.com/foo
    body:
      encoding: UTF-8
      string: ""
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "5"
    body:
      encoding: UTF-8
      string: Hello
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
recorded_with: VCR 2.0.0
YAML

# Cassette for method matching tests (POST and GET)
METHOD_MATCHING_CASSETTE_YAML = <<-YAML
---
http_interactions:
- request:
    method: post
    uri: http://post-request.com/
    body:
      encoding: UTF-8
      string: ""
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "13"
    body:
      encoding: UTF-8
      string: post response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
- request:
    method: get
    uri: http://get-request.com/
    body:
      encoding: UTF-8
      string: ""
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "12"
    body:
      encoding: UTF-8
      string: get response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
recorded_with: VCR 2.0.0
YAML

# Cassette for host matching tests
HOST_MATCHING_CASSETTE_YAML = <<-YAML
---
http_interactions:
- request:
    method: post
    uri: http://host1.com/some/long/path
    body:
      encoding: UTF-8
      string: ""
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "14"
    body:
      encoding: UTF-8
      string: host1 response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
- request:
    method: post
    uri: http://host2.com/some/other/long/path
    body:
      encoding: UTF-8
      string: ""
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "14"
    body:
      encoding: UTF-8
      string: host2 response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
recorded_with: VCR 2.0.0
YAML

# Cassette for path matching tests
PATH_MATCHING_CASSETTE_YAML = <<-YAML
---
http_interactions:
- request:
    method: post
    uri: http://host1.com/about?date=2011-09-01
    body:
      encoding: UTF-8
      string: ""
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "14"
    body:
      encoding: UTF-8
      string: about response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
- request:
    method: post
    uri: http://host2.com/home?date=2011-09-01
    body:
      encoding: UTF-8
      string: ""
    headers: {}
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Length:
      - "13"
    body:
      encoding: UTF-8
      string: home response
    http_version: "1.1"
  recorded_at: Tue, 01 Nov 2011 04:58:44 GMT
recorded_with: VCR 2.0.0
YAML
