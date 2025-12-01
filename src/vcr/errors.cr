module VCR
  # Namespace for VCR errors.
  module Errors
    # Base class for all VCR errors.
    class Error < Exception; end

    # Error raised when VCR is turned off while a cassette is in use.
    # @see VCR#turn_off!
    # @see VCR#turned_off
    class CassetteInUseError < Error; end

    # Error raised when a VCR cassette is inserted while VCR is turned off.
    # @see VCR#insert_cassette
    # @see VCR#use_cassette
    class TurnedOffError < Error; end

    # Error raised when a cassette ECR template is rendered and a
    # variable is missing.
    # @see VCR#insert_cassette
    # @see VCR#use_cassette
    class MissingECRVariableError < Error; end

    # Error raised when the version of one of the libraries that VCR hooks into
    # is too low for VCR to support.
    # @see VCR::Configuration#hook_into
    class LibraryVersionTooLowError < Error; end

    # Error raised when a request matcher is requested that is not registered.
    class UnregisteredMatcherError < Error; end

    # Error raised when a VCR 1.x cassette is used with VCR 2.
    class InvalidCassetteFormatError < Error; end

    # Error raised when an `around_http_request` hook is used improperly.
    # @see VCR::Configuration#around_http_request
    class AroundHTTPRequestHookError < Error; end

    # Error raised when you attempt to use a VCR feature that is not
    # supported on your ruby interpreter.
    # @see VCR::Configuration#around_http_request
    class NotSupportedError < Error; end

    # Error raised when you ask VCR to decode a compressed response
    # body but the content encoding isn't one of the known ones.
    # @see VCR::Response#decompress
    class UnknownContentEncodingError < Error; end

    # Error raised when you eject a cassette before all previously
    # recorded HTTP interactions are played back.
    # @note Only applicable when :allow_episode_skipping is false.
    # @see VCR::HTTPInteractionList#assert_no_unused_interactions!
    class UnusedHTTPInteractionError < Error; end

    # Error raised when you attempt to eject a cassette inserted by another
    # thread.
    class EjectLinkedCassetteError < Error; end

    # Error raised when an HTTP request is made that VCR is unable to handle.
    # @note VCR will raise this to force you to do something about the
    #  HTTP request. The idea is that you want to handle _every_ HTTP
    #  request in your test suite. The error message will give you
    #  suggestions for how to deal with the request.
    class UnhandledHTTPRequestError < Error
      getter request : Request
      @documentation_version_slug : String?
      @cassettes : Array(Cassette)?

      # Constructs the error.
      #
      # @param [VCR::Request] request the unhandled request.
      def initialize(request)
        @request = request
        super construct_message
      end

      private def documentation_version_slug
        @documentation_version_slug ||= VCR.version.gsub(/\W/, "-")
      end

      private def construct_message
        ["", "", "=" * 80,
         "An HTTP request has been made that VCR does not know how to handle:",
         "#{request_description}\n",
         cassettes_description,
         formatted_suggestions,
         "=" * 80, "", ""].join("
")
      end

      private def current_cassettes
        @cassettes ||= VCR.cassettes.to_a.reverse
      end

      private def request_description
        lines = [] of String

        lines << "  #{request.method.to_s.upcase} #{request.uri}"

        if match_request_on_headers?
          lines << "  Headers:
#{formatted_headers}"
        end
        if match_request_on_body?
          lines << "  Body: #{request.body}"
        end
        lines.join("
")
      end

      private def match_request_on_headers?
        current_matchers.includes?(:headers)
      end

      private def match_request_on_body?
        current_matchers.includes?(:body)
      end

      private def current_matchers : Array(Symbol)
        if current_cassettes.size > 0
          current_cassettes.reduce([] of Symbol) do |memo, cassette|
            memo | cassette.match_requests_on
          end
        else
          matchers = VCR.configuration.default_cassette_options[:match_requests_on]?
          case matchers
          when Array(Symbol)
            matchers
          else
            [:method, :uri]
          end
        end
      end

      private def formatted_headers
        request.headers.flat_map do |header, values|
          values.map do |val|
            "    #{header}: #{val.inspect}"
          end
        end.join("
")
      end

      private def cassettes_description
        if current_cassettes.size > 0
          [cassettes_list + "\n",
           "Under the current configuration VCR can not find a suitable HTTP interaction",
           "to replay and is prevented from recording new requests. There are a few ways",
           "you can deal with this:\n"].join("
")
        else
          ["There is currently no cassette in use. There are a few ways",
           "you can configure VCR to handle this request:\n"].join("
")
        end
      end

      private def cassettes_list
        lines = [] of String

        lines << if current_cassettes.size == 1
          "VCR is currently using the following cassette:"
        else
          "VCR are currently using the following cassettes:"
        end

        lines = current_cassettes.reduce(lines) do |memo, cassette|
          memo.concat([
            "  - #{cassette.file}",
            "    - :record => #{cassette.record_mode.inspect}",
            "    - :match_requests_on => #{cassette.match_requests_on.inspect}",
          ])
        end

        lines.join("
")
      end

      private def formatted_suggestions
        formatted_points = [] of String
        formatted_foot_notes = [] of String
        suggestions.each_with_index do |suggestion, index|
          bullet_point = suggestion.first
          foot_note = suggestion.last
          formatted_points << format_bullet_point(bullet_point, index)
          formatted_foot_notes << format_foot_note(foot_note, index)
        end

        [
          formatted_points.join("\n"),
          formatted_foot_notes.join("\n"),
        ].join("

")
      end

      private def format_bullet_point(lines : Array(String), index : Int32) : String
        result = lines.dup
        result[0] = "  * " + result[0]
        result[-1] = result[-1] + " [#{index + 1}]."
        result.join("\n    ")
      end

      private def format_foot_note(url : String, index : Int32)
        "[#{index + 1}] #{url % documentation_version_slug}"
      end

      # List of suggestions for how to configure VCR to handle the request.
      ALL_SUGGESTIONS = {
        :use_new_episodes => [
          ["You can use the :new_episodes record mode to allow VCR to",
           "record this new request to the existing cassette"],
          "https://benoittgt.github.io/vcr/?v=%s#/record_modes/new_episodes",
        ],
        :delete_cassette_for_once => [
          ["The current record mode (:once) does not allow new requests to be recorded",
           "to a previously recorded cassette. You can delete the cassette file and re-run",
           "your tests to allow the cassette to be recorded with this request"],
          "https://benoittgt.github.io/vcr/?v=%s#/record_modes/once",
        ],
        :deal_with_none => [
          ["The current record mode (:none) does not allow requests to be recorded. You",
           "can temporarily change the record mode to :once, delete the cassette file ",
           "and re-run your tests to allow the cassette to be recorded with this request"],
          "https://benoittgt.github.io/vcr/?v=%s#/record_modes/none",
        ],
        :none_without_file => [
          ["The current record mode (:none) does not allow requests to be recorded.",
           "One or more cassette names registered was not found. Use ",
           ":new_episodes or :once record modes to record a new cassette"],
          "https://benoittgt.github.io/vcr/?v=%s#/record_modes/none",
        ],
        :use_a_cassette => [
          ["If you want VCR to record this request and play it back during future test",
           "runs, you should wrap your test (or this portion of your test) in a",
           "`VCR.use_cassette` block"],
          "https://benoittgt.github.io/vcr/?v=%s#/getting_started",
        ],
        :allow_http_connections_when_no_cassette => [
          ["If you only want VCR to handle requests made while a cassette is in use,",
           "configure `allow_http_connections_when_no_cassette = true`. VCR will",
           "ignore this request since it is made when there is no cassette"],
          "https://benoittgt.github.io/vcr/?v=%s#/configuration/allow_http_connections_when_no_cassette",
        ],
        :ignore_request => [
          ["If you want VCR to ignore this request (and others like it), you can",
           "set an `ignore_request` callback"],
          "https://benoittgt.github.io/vcr/?v=%s#/configuration/ignore_request",
        ],
        :allow_playback_repeats => [
          ["The cassette contains an HTTP interaction that matches this request,",
           "but it has already been played back. If you wish to allow a single HTTP",
           "interaction to be played back multiple times, set the `:allow_playback_repeats`",
           "cassette option"],
          "https://benoittgt.github.io/vcr/?v=%s#/request_matching/playback_repeats",
        ],
        :match_requests_on => [
          ["The cassette contains %s not been",
           "played back. If your request is non-deterministic, you may need to",
           "change your :match_requests_on cassette option to be more lenient",
           "or use a custom request matcher to allow it to match"],
          "https://benoittgt.github.io/vcr/?v=%s#/request_matching",
        ],
        :try_debug_logger => [
          ["If you're surprised VCR is raising this error",
           "and want insight about how VCR attempted to handle the request,",
           "you can use the debug_logger configuration option to log more details"],
          "https://benoittgt.github.io/vcr/?v=%s#/configuration/debug_logging",
        ],
      }

      private def suggestion_for(key : Symbol) : Tuple(Array(String), String)
        suggestion = ALL_SUGGESTIONS[key]
        bullet_point_lines = suggestion[0].as(Array(String)).dup
        url = suggestion[1].as(String).dup
        {bullet_point_lines, url}
      end

      private def suggestions
        return no_cassette_suggestions if current_cassettes.size == 0

        suggestion_keys = [:try_debug_logger, :use_new_episodes, :ignore_request]
        suggestion_keys.concat(record_mode_suggestion)
        suggestion_keys << :allow_playback_repeats if has_used_interaction_matching?

        result = suggestion_keys.map { |k| suggestion_for(k) }
        result.concat(match_requests_on_suggestion)
        result
      end

      private def no_cassette_suggestions
        [:try_debug_logger, :use_a_cassette, :allow_http_connections_when_no_cassette, :ignore_request].map do |key|
          suggestion_for(key)
        end
      end

      private def record_mode_suggestion : Array(Symbol)
        record_modes = current_cassettes.map &.record_mode

        if record_modes.all? { |r| r == :none }
          none_suggestion
        elsif record_modes.all? { |r| r == :once }
          [:delete_cassette_for_once]
        else
          [] of Symbol
        end
      end

      private def none_suggestion : Array(Symbol)
        if current_cassettes.any? { |c| (file = c.file).nil? || !File.exists?(file) }
          [:none_without_file]
        else
          [:deal_with_none]
        end
      end

      private def has_used_interaction_matching?
        current_cassettes.any? { |c| c.http_interactions.has_used_interaction_matching?(request) }
      end

      private def match_requests_on_suggestion : Array(Tuple(Array(String), String))
        num_remaining_interactions = current_cassettes.reduce(0) { |sum, c| sum + c.http_interactions.remaining_unused_interaction_count }

        return [] of Tuple(Array(String), String) if num_remaining_interactions.zero?
        interaction_description = if num_remaining_interactions == 1
                                    "1 HTTP interaction that has"
                                  else
                                    "#{num_remaining_interactions} HTTP interactions that have"
                                  end

        description_lines, link = suggestion_for(:match_requests_on)
        description_lines[0] = description_lines[0] % interaction_description
        [{description_lines, link}]
      end
    end
  end
end
