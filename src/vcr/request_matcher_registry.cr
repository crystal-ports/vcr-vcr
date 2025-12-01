require "./errors"

require "json"

module VCR
  # Keeps track of the different request matchers.
  class RequestMatcherRegistry
    # The default request matchers used for any cassette that does not
    # specify request matchers.
    DEFAULT_MATCHERS = [:method, :uri]

    # @private
    class Matcher
      getter callable : Proc(Request, Request, Bool)

      def initialize(@callable : Proc(Request, Request, Bool))
      end

      def matches?(request_1 : Request, request_2 : Request) : Bool
        callable.call(request_1, request_2)
      end
    end

    # @private
    class URIWithoutParamsMatcher
      getter params_to_ignore : Array(String)

      def initialize(@params_to_ignore : Array(String))
      end

      def partial_uri_from(request : Request) : URI
        uri = request.parsed_uri.dup
        if query = uri.query
          filtered_params = query.split("&").reject do |p|
            parts = p.split("=", 2)
            key = parts[0].gsub(/\[\]\z/, "") # handle params like tag[]=
            params_to_ignore.includes?(key)
          end
          uri.query = filtered_params.empty? ? nil : filtered_params.join("&")
        end
        uri
      end

      def call(request_1 : Request, request_2 : Request) : Bool
        partial_uri_from(request_1) == partial_uri_from(request_2)
      end

      def to_proc : Proc(Request, Request, Bool)
        ->(r1 : Request, r2 : Request) { call(r1, r2) }
      end
    end

    # @private
    def initialize
      @registry = {} of Symbol => Matcher
      register_built_ins
    end

    # @private
    def register(name : Symbol, &block : Request, Request -> Bool)
      if @registry.has_key?(name)
        STDERR.puts "WARNING: There is already a VCR request matcher registered for #{name.inspect}. Overriding it."
      end
      @registry[name] = Matcher.new(block)
    end

    # @private
    def [](matcher : Symbol) : Matcher
      @registry.fetch(matcher) { raise_unregistered_matcher_error(matcher) }
    end

    def [](matcher : Proc(Request, Request, Bool)) : Matcher
      Matcher.new(matcher)
    end

    # Builds a dynamic request matcher that matches on a URI while ignoring the
    # named query parameters. This is useful for dealing with non-deterministic
    # URIs (i.e. that have a timestamp or request signature parameter).
    #
    # @example
    #   without_timestamp = VCR.request_matchers.uri_without_param(:timestamp)
    #
    #   # use it directly...
    #   VCR.use_cassette('example', :match_requests_on => [:method, without_timestamp]) { }
    #
    #   # ...or register it as a named matcher
    #   VCR.configure do |c|
    #     c.register_request_matcher(:uri_without_timestamp, &without_timestamp)
    #   end
    #
    #   VCR.use_cassette('example', :match_requests_on => [:method, :uri_without_timestamp]) { }
    #
    # @param ignores [Array<#to_s>] The names of the query parameters to ignore
    # @return [#call] the request matcher
    def uri_without_params(*ignores : String) : URIWithoutParamsMatcher
      params = ignores.to_a
      uri_without_param_matchers[params] ||= URIWithoutParamsMatcher.new(params)
    end

    def uri_without_param(*ignores : String) : URIWithoutParamsMatcher
      uri_without_params(*ignores)
    end

    private def uri_without_param_matchers : Hash(Array(String), URIWithoutParamsMatcher)
      @uri_without_param_matchers ||= {} of Array(String) => URIWithoutParamsMatcher
    end

    private def raise_unregistered_matcher_error(name : Symbol) : NoReturn
      raise Errors::UnregisteredMatcherError.new(
        "There is no matcher registered for #{name.inspect}. " +
        "Did you mean one of #{@registry.keys.map(&.inspect).join(", ")}?"
      )
    end

    private def register_built_ins
      register(:method) { |r1, r2| r1.method == r2.method }
      register(:uri) { |r1, r2| r1.parsed_uri == r2.parsed_uri }
      register(:body) { |r1, r2| r1.body == r2.body }
      register(:headers) { |r1, r2| r1.headers == r2.headers }

      register(:host) do |r1, r2|
        (r1.parsed_uri.host || "").chomp(".") == (r2.parsed_uri.host || "").chomp(".")
      end
      register(:path) do |r1, r2|
        r1.parsed_uri.path == r2.parsed_uri.path
      end

      register(:query) do |r1, r2|
        query1 = r1.parsed_uri.query.to_s
        query2 = r2.parsed_uri.query.to_s
        if parser = VCR.configuration.query_parser
          parser.call(query1) == parser.call(query2)
        else
          query1 == query2
        end
      end

      try_to_register_body_as_json
      try_to_register_body_as_graphql
    end

    private def try_to_register_body_as_json
      register(:body_as_json) do |r1, r2|
        body1 = r1.body
        body2 = r2.body
        if body1 == body2
          true
        elsif body1 && body2
          begin
            JSON.parse(body1) == JSON.parse(body2)
          rescue JSON::ParseException
            false
          end
        else
          false
        end
      end
    end

    # Registers the :body_as_graphql matcher that normalizes GraphQL queries
    # before comparison. This handles whitespace differences and field ordering
    # in GraphQL query strings while comparing variables separately as JSON.
    private def try_to_register_body_as_graphql
      register(:body_as_graphql) do |r1, r2|
        body1 = r1.body
        body2 = r2.body

        if body1 == body2
          true
        elsif body1 && body2
          graphql_bodies_match?(body1, body2)
        else
          false
        end
      end
    end

    private def graphql_bodies_match?(body1 : String, body2 : String) : Bool
      json1 = JSON.parse(body1)
      json2 = JSON.parse(body2)

      query1 = json1["query"]?.try(&.as_s?)
      query2 = json2["query"]?.try(&.as_s?)

      return false unless query1 && query2

      normalized1 = normalize_graphql_query(query1)
      normalized2 = normalize_graphql_query(query2)

      return false unless normalized1 == normalized2

      vars1 = json1["variables"]?
      vars2 = json2["variables"]?

      vars1 == vars2
    rescue JSON::ParseException
      false
    end

    private def normalize_graphql_query(query : String) : String
      document = GraphQL::Language.parse(query)
      document.to_s.gsub(/\s+/, " ").strip
    rescue
      query.gsub(/\s+/, " ").strip
    end
  end
end
