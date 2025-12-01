require "set"

module VCR
  # @private
  class RequestIgnorer
    LOCALHOST_ALIASES = ["localhost", "127.0.0.1", "0.0.0.0", "host.docker.internal"]

    @ignored_hosts : Set(String)
    @ignore_request_hooks : Array(Proc(Request, Bool))

    def initialize
      @ignored_hosts = Set(String).new
      @ignore_request_hooks = [] of Proc(Request, Bool)

      # Default hook to check against ignored hosts list
      ignore_request do |request|
        host = request.parsed_uri.host
        host ? @ignored_hosts.includes?(host) : false
      end
    end

    def ignore_request(&block : Request -> Bool)
      @ignore_request_hooks << block
    end

    def ignore_localhost=(value : Bool)
      if value
        LOCALHOST_ALIASES.each { |h| ignore_hosts(h) }
      else
        LOCALHOST_ALIASES.each { |h| @ignored_hosts.delete(h) }
      end
    end

    def localhost_ignored? : Bool
      (LOCALHOST_ALIASES.to_set & @ignored_hosts).any?
    end

    def ignore_hosts(*hosts : String)
      @ignored_hosts.concat(hosts.to_a)
    end

    def unignore_hosts(*hosts : String)
      hosts.each { |h| @ignored_hosts.delete(h) }
    end

    def ignore?(request : Request) : Bool
      @ignore_request_hooks.any?(&.call(request))
    end
  end
end
