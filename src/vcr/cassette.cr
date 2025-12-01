require "./cassette/http_interaction_list"
require "./cassette/ecr_renderer"
require "./cassette/serializers"

require "./util/logger"

module VCR
  # Type alias for cassette options
  alias CassetteOptions = Hash(Symbol, Symbol | Bool | Array(Symbol) | Hash(String, String) | Int32 | String | Nil)

  # The media VCR uses to store HTTP interactions for later re-use.
  class Cassette
    include Logger::Mixin

    # The supported record modes.
    #
    #   * :all -- Record every HTTP interactions; do not play any back.
    #   * :none -- Do not record any HTTP interactions; play them back.
    #   * :new_episodes -- Playback previously recorded HTTP interactions and record new ones.
    #   * :once -- Record the HTTP interactions if the cassette has not already been recorded;
    #              otherwise, playback the HTTP interactions.
    VALID_RECORD_MODES = [:all, :none, :new_episodes, :once]

    # Type annotations for instance variables
    @name : String
    @options : CassetteOptions
    @record_mode : Symbol
    @record_on_error : Bool
    @match_requests_on : Array(Symbol)
    @ecr : Hash(String, String) | Bool | Nil
    @re_record_interval : Int32?
    @clean_outdated_http_interactions : Bool
    @drop_unused_requests : Bool
    @tags : Array(Symbol)?
    @run_failed : Bool
    @new_recorded_interactions : Array(HTTPInteraction)
    @http_interactions : HTTPInteractionList?
    @mutex : Mutex
    @allow_playback_repeats : Bool
    @allow_unused_http_interactions : Bool
    @exclusive : Bool
    @parent_list : HTTPInteractionList?
    # FileSystem is a module with extend self, so we store a reference to the module type
    @persister : Persisters::FileSystem.class = Persisters::FileSystem
    @serializer : SerializerInterface
    @originally_recorded_at : Time?
    @storage_key : String?
    @previously_recorded_interactions : Array(HTTPInteraction)?
    @deserialized_hash : Hash(String, YAML::Any)?

    getter name : String
    getter record_mode : Symbol
    getter? record_on_error : Bool
    getter match_requests_on : Array(Symbol)
    getter ecr : Hash(String, String) | Bool | Nil
    getter re_record_interval : Int32?
    getter? clean_outdated_http_interactions : Bool
    getter? drop_unused_requests : Bool
    getter tags : Array(Symbol)?

    # @param (see VCR#insert_cassette)
    # @see VCR#insert_cassette
    def initialize(name : String, options : CassetteOptions = CassetteOptions.new)
      @name = name
      @options = self.class.merge_options(options)
      @mutex = Mutex.new
      @run_failed = false
      @new_recorded_interactions = [] of HTTPInteraction

      @record_mode = @options[:record]?.try(&.as(Symbol)) || :once
      @record_on_error = !!@options[:record_on_error]?
      @match_requests_on = @options[:match_requests_on]?.try(&.as(Array(Symbol))) || [:method, :uri]
      @ecr = self.class.extract_ecr_option(@options)
      @re_record_interval = @options[:re_record_interval]?.try(&.as(Int32))
      @clean_outdated_http_interactions = !!@options[:clean_outdated_http_interactions]?
      @drop_unused_requests = !!@options[:drop_unused_requests]?
      @tags = self.class.extract_tags(@options)
      @allow_playback_repeats = !!@options[:allow_playback_repeats]?
      @allow_unused_http_interactions = @options[:allow_unused_http_interactions]? != false
      @exclusive = !!@options[:exclusive]?
      @parent_list = nil
      @persister = Persisters::FileSystem
      @serializer = VCR.cassette_serializers[@options[:serialize_with]?.try(&.as(Symbol)) || :yaml]

      assert_valid_options!
      raise_error_unless_valid_record_mode

      log "Initialized with options: #{@options.inspect}"
    end

    protected def self.merge_options(options : CassetteOptions) : CassetteOptions
      merged = CassetteOptions.new
      VCR.configuration.default_cassette_options.each { |k, v| merged[k] = v }
      options.each { |k, v| merged[k] = v }
      merged
    end

    protected def self.extract_ecr_option(options : CassetteOptions) : Bool | Hash(String, String) | Nil
      options[:ecr]?.try do |e|
        case e
        when Bool                 then e
        when Hash(String, String) then e
        else                           nil
        end
      end
    end

    protected def self.extract_tags(options : CassetteOptions) : Array(Symbol)
      tags = [] of Symbol

      if tags_option = options[:tags]?
        case tags_option
        when Array(Symbol) then tags = tags_option.dup
        when Symbol        then tags << tags_option
        end
      end
      tags << options[:tag]?.as(Symbol) if options[:tag]?.is_a?(Symbol)

      # Add special option tags
      tags << :update_content_length_header if options[:update_content_length_header]?
      tags << :preserve_exact_body_bytes if options[:preserve_exact_body_bytes]?
      tags << :decode_compressed_response if options[:decode_compressed_response]?
      tags << :recompress_response if options[:recompress_response]?

      tags
    end

    # Ejects the current cassette. The cassette will no longer be used.
    # In addition, any newly recorded HTTP interactions will be written to
    # disk.
    #
    # @note This is not intended to be called directly. Use `VCR.eject_cassette` instead.
    #
    # @param (see VCR#eject_casssette)
    # @see VCR#eject_cassette
    def eject(options : CassetteOptions = CassetteOptions.new)
      write_recorded_interactions_to_disk if should_write_recorded_interactions_to_disk?
      if should_assert_no_unused_interactions? && !options[:skip_no_unused_interactions_assertion]?
        http_interactions.assert_no_unused_interactions!
      end
    end

    # @private
    def run_failed!
      @run_failed = true
    end

    # @private
    def run_failed?
      @run_failed = false unless @run_failed
      @run_failed
    end

    def should_write_recorded_interactions_to_disk?
      !run_failed? || record_on_error?
    end

    # @private
    def http_interactions
      # Without this mutex, under threaded access, an HTTPInteractionList will overwrite
      # the first.
      @mutex.synchronize do
        interactions = should_stub_requests? ? previously_recorded_interactions : [] of HTTPInteraction
        parent = @parent_list || HTTPInteractionList::NullList
        @http_interactions ||= HTTPInteractionList.new(
          interactions,
          match_requests_on,
          @allow_playback_repeats,
          parent,
          log_prefix
        )
      end
    end

    # @private
    def record_http_interaction(interaction : HTTPInteraction)
      VCR::CassetteMutex.synchronize do
        log "Recorded HTTP interaction #{request_summary(interaction.request)} => #{response_summary(interaction.response)}"
        new_recorded_interactions << interaction
      end
    end

    # @private
    def new_recorded_interactions
      @new_recorded_interactions ||= [] of HTTPInteraction
    end

    # @return [String] The file for this cassette.
    # @raise [NotImplementedError] if the configured cassette persister
    #  does not support resolving file paths.
    # @note VCR will take care of sanitizing the cassette name to make it a valid file name.
    def file
      unless @persister.responds_to?(:absolute_path_to_file)
        raise NotImplementedError.new("The configured cassette persister does not support resolving file paths")
      end
      @persister.absolute_path_to_file(storage_key)
    end

    # @return [Boolean] Whether or not the cassette is recording.
    def recording?
      case record_mode
      when :none; false
      when :once; raw_cassette_bytes.to_s.empty?
      else        true
      end
    end

    # @return [Hash] The hash that will be serialized when the cassette is written to disk.
    def serializable_hash
      {
        "http_interactions" => interactions_to_record.map &.to_hash,
        "recorded_with"     => "VCR #{VCR.version}",
      }
    end

    # @return [Time, nil] The `recorded_at` time of the first HTTP interaction
    #                     or nil if the cassette has no prior HTTP interactions.
    #
    # @example
    #
    #   VCR.use_cassette("some cassette") do |cassette|
    #     Timecop.freeze(cassette.originally_recorded_at || Time.now) do
    #       # ...
    #     end
    #   end
    def originally_recorded_at
      @originally_recorded_at ||= previously_recorded_interactions.map &.recorded_at.min
    end

    # @return [Boolean] false unless wrapped with LinkedCassette
    def linked?
      false
    end

    private def assert_valid_options!
      invalid_options = @options.keys - [
        :record, :record_on_error, :ecr, :match_requests_on, :re_record_interval, :tag, :tags,
        :update_content_length_header, :allow_playback_repeats, :allow_unused_http_interactions,
        :exclusive, :serialize_with, :preserve_exact_body_bytes, :decode_compressed_response,
        :recompress_response, :persist_with, :persister_options, :clean_outdated_http_interactions,
        :drop_unused_requests,
      ]

      if invalid_options.size > 0
        raise ArgumentError.new("You passed the following invalid options to VCR::Cassette.new: #{invalid_options.inspect}.")
      end
    end

    private def extract_options
      # Extract options explicitly instead of using instance_variable_set
      @record_on_error = @options[:record_on_error]?
      @ecr = @options[:ecr]?
      @match_requests_on = @options[:match_requests_on]? || [:method, :uri]
      @re_record_interval = @options[:re_record_interval]?
      @clean_outdated_http_interactions = @options[:clean_outdated_http_interactions]?
      @allow_playback_repeats = @options[:allow_playback_repeats]?
      @allow_unused_http_interactions = @options[:allow_unused_http_interactions]?
      @exclusive = @options[:exclusive]?
      @drop_unused_requests = @options[:drop_unused_requests]?

      assign_tags

      @serializer = VCR.cassette_serializers[@options[:serialize_with]? || :yaml]
      @persister = VCR.cassette_persisters[@options[:persist_with]? || :file_system]
      @record_mode = should_re_record?(@options[:record]?) ? :all : (@options[:record]? || :once)
      @parent_list = @exclusive ? HTTPInteractionList::NullList : VCR.http_interactions
    end

    private def assign_tags
      tags_option = @options[:tags]? || @options[:tag]?
      @tags = tags_option.is_a?(Array) ? tags_option.map(&.to_s.to_sym) : (tags_option ? [tags_option.to_s.to_sym] : [] of Symbol)

      [:update_content_length_header, :preserve_exact_body_bytes, :decode_compressed_response, :recompress_response].each do |tag|
        @tags << tag if @options[tag]?
      end
    end

    private def previously_recorded_interactions : Array(HTTPInteraction)
      if interactions = @previously_recorded_interactions
        return interactions
      end

      result = if !raw_cassette_bytes.to_s.empty?
                 interactions_data = deserialized_hash["http_interactions"].as_a
                 interactions = interactions_data.map { |h| HTTPInteraction.from_hash(h) }
                 invoke_hook(:before_playback, interactions)
                 interactions.reject! do |i|
                   i.request.uri.is_a?(String) && VCR.request_ignorer.ignore?(i.request)
                 end
                 interactions
               else
                 [] of HTTPInteraction
               end
      @previously_recorded_interactions = result
    end

    private def storage_key
      @storage_key ||= [name, @serializer.file_extension].join(".")
    end

    private def raise_error_unless_valid_record_mode
      unless VALID_RECORD_MODES.includes?(record_mode)
        raise ArgumentError.new("#{record_mode} is not a valid cassette record mode.  Valid modes are: #{VALID_RECORD_MODES.inspect}")
      end
    end

    private def should_re_record?(record_mode)
      interval = @re_record_interval
      return false if interval.nil?
      recorded_at = originally_recorded_at
      return false if recorded_at.nil?
      return false if record_mode == :none
      now = Time.local

      result = (recorded_at + interval.seconds) < now
      info = "previously recorded at: '#{recorded_at}'; now: '#{now}'; interval: #{interval} seconds"
      if !result
        log "Not re-recording since the interval has not elapsed (#{info})."
      else
        log "re-recording (#{info})."
      end
      result
    end

    private def should_stub_requests?
      record_mode != :all
    end

    private def should_remove_matching_existing_interactions?
      record_mode == :all
    end

    private def should_remove_unused_interactions?
      @drop_unused_requests
    end

    private def should_assert_no_unused_interactions?
      # In Ruby, this checked $! (current exception). In Crystal, we use run_failed?
      !(@allow_unused_http_interactions || run_failed?)
    end

    private def raw_cassette_bytes
      @raw_cassette_bytes ||= VCR::Cassette::ECRRenderer.new(@persister[storage_key], ecr, name).render
    end

    private def merged_interactions
      old_interactions = previously_recorded_interactions

      if should_remove_matching_existing_interactions?
        new_interaction_list = HTTPInteractionList.new(new_recorded_interactions, match_requests_on)
        old_interactions = old_interactions.reject do |i|
          new_interaction_list.response_for(i.request)
        end
      end
      if should_remove_unused_interactions?
        new_recorded_interactions
      else
        up_to_date_interactions(old_interactions) + new_recorded_interactions
      end
    end

    private def up_to_date_interactions(interactions)
      interval = re_record_interval
      return interactions unless clean_outdated_http_interactions? && interval
      interactions.take_while do |x|
        recorded_at = x.recorded_at
        recorded_at ? recorded_at > Time.local - interval.seconds : true
      end
    end

    private def interactions_to_record
      # We deep-dup the interactions by roundtripping them to/from a hash.
      # This is necessary because `before_record` can mutate the interactions.
      merged_interactions.map { |i| HTTPInteraction.from_hash(i.to_hash) }.tap do |interactions|
        invoke_hook(:before_record, interactions)
      end
    end

    private def write_recorded_interactions_to_disk
      return if new_recorded_interactions.none?
      hash = serializable_hash
      interactions = hash["http_interactions"]
      return if interactions.is_a?(Array) && interactions.empty?
      @persister[storage_key] = @serializer.serialize(hash)
    end

    private def invoke_hook(type_ : Symbol, interactions : Array(HTTPInteraction))
      # Create HookAware wrappers and invoke configuration hooks for each interaction.
      # This is critical for features like filter_sensitive_data to work.
      interactions.each do |interaction|
        hook_aware = interaction.hook_aware
        VCR.configuration.invoke_hook(type_, hook_aware, self)
      end

      # Remove any interactions that were marked as ignored by hooks
      interactions.reject!(&.hook_aware.ignored?)
    end

    private def deserialized_hash : Hash(String, YAML::Any)
      if hash = @deserialized_hash
        return hash
      end

      bytes = raw_cassette_bytes || ""
      parsed = @serializer.deserialize(bytes)

      # Handle YAML::Any wrapper by extracting the underlying hash
      result = case parsed
               when YAML::Any
                 if parsed.as_h?
                   hash = {} of String => YAML::Any
                   parsed.as_h.each { |k, v| hash[k.as_s] = v }
                   hash
                 else
                   nil
                 end
               when Hash(String, YAML::Any)
                 parsed
               else
                 nil
               end

      unless result && result["http_interactions"]?.try(&.as_a?)
        raise Errors::InvalidCassetteFormatError.new(
          "#{file} does not appear to be a valid VCR 2.0 cassette. " +
          "VCR 1.x cassettes are not valid with VCR 2.0. When upgrading from " +
          "VCR 1.x, it is recommended that you delete all your existing cassettes and " +
          "re-record them, or use the provided vcr:migrate_cassettes rake task to migrate " +
          "them. For more info, see the VCR upgrade guide."
        )
      end
      @deserialized_hash = result
    end

    private def log_prefix
      @log_prefix ||= "[Cassette: '#{name}'] "
    end

    private def request_summary(request)
      super(request, match_requests_on)
    end
  end
end
