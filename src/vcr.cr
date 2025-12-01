# The main entry point for VCR.
# @note This module is extended onto itself; thus, the methods listed
#  here as instance methods are available directly off of VCR.
require "graphql"

require "./vcr/util/logger"
require "./vcr/util/variable_args_block_caller"
require "./vcr/util/version_checker"

require "./vcr/cassette"
require "./vcr/cassette/serializers"
require "./vcr/cassette/persisters"
require "./vcr/linked_cassette"
require "./vcr/configuration"
require "./vcr/errors"
require "./vcr/library_hooks"
require "./vcr/request_ignorer"
require "./vcr/request_matcher_registry"
require "./vcr/structs"
require "./vcr/version"
require "./vcr/http_client_hook"

require "fiber"

module VCR
  include VariableArgsBlockCaller
  include Errors

  extend self

  # Mutex to synchronize access to cassettes in a threaded environment
  CassetteMutex = Mutex.new

  # The main thread in which VCR was loaded
  MainThread = Thread.current

  module RSpec
  end

  module Middleware
  end

  # The currently active cassette.
  #
  # @return [nil, VCR::Cassette] The current cassette or nil if there is
  #  no current cassette.
  def current_cassette : Cassette?
    cassettes.last?
  end

  # Inserts the named cassette using the given cassette options.
  # New HTTP interactions, if allowed by the cassette's `:record` option, will
  # be recorded to the cassette. The cassette's existing HTTP interactions
  # will be used to stub requests, unless prevented by the cassette's
  # `:record` option.
  #
  # @example
  #   VCR.insert_cassette('twitter', :record => :new_episodes)
  #
  #   # ...later, after making an HTTP request:
  #
  #   VCR.eject_cassette
  #
  # @param name [#to_s] The name of the cassette. VCR will sanitize
  #                     this to ensure it is a valid file name.
  # @param options [Hash] The cassette options. The given options will
  #  be merged with the configured default_cassette_options.
  # @option options :record [:all, :none, :new_episodes, :once] The record mode.
  # @option options :ecr [Boolean, Hash] Whether or not to evaluate the
  #  cassette as an ECR template. Defaults to false. A hash can be used
  #  to provide the ECR template with local variables.
  # @option options :match_requests_on [Array<Symbol, #call>] List of request matchers
  #  to use to determine what recorded HTTP interaction to replay. Defaults to
  #  [:method, :uri]. The built-in matchers are :method, :uri, :host, :path, :headers
  #  and :body. You can also pass the name of a registered custom request matcher or
  #  any object that responds to #call.
  # @option options :re_record_interval [Integer] When given, the
  #  cassette will be re-recorded at the given interval, in seconds.
  # @option options :tag [Symbol] Used to apply tagged `before_record`
  #  and `before_playback` hooks to the cassette.
  # @option options :tags [Array<Symbol>] Used to apply multiple tags to
  #  a cassette so that tagged `before_record` and `before_playback` hooks
  #  will apply to the cassette.
  # @option options :update_content_length_header [Boolean] Whether or
  #  not to overwrite the Content-Length header of the responses to
  #  match the length of the response body. Defaults to false.
  # @option options :decode_compressed_response [Boolean] Whether or
  #  not to decode compressed responses before recording the cassette.
  #  This makes the cassette more human readable. Defaults to false.
  # @option options :allow_playback_repeats [Boolean] Whether or not to
  #  allow a single HTTP interaction to be played back multiple times.
  #  Defaults to false.
  # @option options :allow_unused_http_interactions [Boolean] If set to
  #  false, an error will be raised if a cassette is ejected before all
  #  previously recorded HTTP interactions have been used.
  #  Defaults to true. Note that when an error has already occurred
  #  (as indicated by the `$!` variable) unused interactions will be
  #  allowed so that we don't silence the original error (which is almost
  #  certainly more interesting/important).
  # @option options :exclusive [Boolean] Whether or not to use only this
  #  cassette and to completely ignore any cassettes in the cassettes stack.
  #  Defaults to false.
  # @option options :serialize_with [Symbol] Which serializer to use.
  #  Valid values are :yaml, :syck, :psych, :json or any registered
  #  custom serializer. Defaults to :yaml.
  # @option options :persist_with [Symbol] Which cassette persister to
  #  use. Defaults to :file_system. You can also register and use a
  #  custom persister.
  # @option options :persister_options [Hash] Pass options to the
  #  persister specified in `persist_with`. Currently available options for the file_system persister:
  #    - `:downcase_cassette_names`: when `true`, names of cassettes will be
  #      normalized in lowercase before reading and writing, which can avoid
  #      confusion when using both case-sensitive and case-insensitive file
  #      systems.
  # @option options :preserve_exact_body_bytes [Boolean] Whether or not
  #  to base64 encode the bytes of the requests and responses for this cassette
  #  when serializing it. See also `VCR::Configuration#preserve_exact_body_bytes`.
  #
  # @return [VCR::Cassette] the inserted cassette
  #
  # @raise [ArgumentError] when the given cassette is already being used.
  # @raise [VCR::Errors::TurnedOffError] when VCR has been turned off
  #  without using the :ignore_cassettes option.
  # @raise [VCR::Errors::MissingECRVariableError] when the `:ecr` option
  #  is used and the ECR template requires variables that you did not provide.
  #
  # @note If you use this method you _must_ call `eject_cassette` when you
  #  are done. It is generally recommended that you use {#use_cassette}
  #  unless your code-under-test cannot be run as a block.
  #
  def insert_cassette(name : String, options : CassetteOptions = CassetteOptions.new)
    if turned_on?
      if cassettes.any? { |c| c.name == name }
        raise ArgumentError.new("There is already a cassette with the same name (#{name}).  You cannot nest multiple cassettes with the same name.")
      end
      cassette = Cassette.new(name, options)
      context_cassettes.push(cassette)
      cassette
    elsif !ignore_cassettes?
      message = "VCR is turned off.  You must turn it on before you can insert a cassette.  " +
                "Or you can use the `:ignore_cassettes => true` option to completely ignore cassette insertions."
      raise TurnedOffError.new(message)
    end
  end

  # Ejects the current cassette. The cassette will no longer be used.
  # In addition, any newly recorded HTTP interactions will be written to
  # disk.
  #
  # @param options [Hash] Eject options.
  # @option options :skip_no_unused_interactions_assertion [Boolean]
  #  If `true` is given, this will skip the "no unused HTTP interactions"
  #  assertion enabled by the `:allow_unused_http_interactions => false`
  #  cassette option. This is intended for use when your test has had
  #  an error, but your test framework has already handled it.
  # @return [VCR::Cassette, nil] the ejected cassette if there was one
  def eject_cassette(options : CassetteOptions = CassetteOptions.new)
    cassette = cassettes.last
    cassette.eject(options) if cassette
    cassette
  ensure
    context_cassettes.delete(cassette)
  end

  # Inserts a cassette using the given name and options, runs the given
  # block, and ejects the cassette.
  #
  # @example
  #   VCR.use_cassette('twitter', :record => :new_episodes) do
  #     # make an HTTP request
  #   end
  #
  # @param (see #insert_cassette)
  # @option (see #insert_cassette)
  # @yield Block to run while this cassette is in use.
  # @yieldparam cassette [(optional) VCR::Cassette] the cassette that has
  #  been inserted.
  # @raise (see #insert_cassette)
  # @return [void]
  # @see #insert_cassette
  # @see #eject_cassette
  def use_cassette(name : String, options : CassetteOptions = CassetteOptions.new, &)
    cassette = insert_cassette(name, options)
    return unless cassette

    begin
      yield
    rescue ex : Exception
      cassette.run_failed!
      raise ex
    ensure
      eject_cassette
    end
  end

  # Inserts multiple cassettes the given names
  #
  # @example
  #   cassettes = [
  #    { name: "github" },
  #    { name: "apple", options: { ecr: true } }
  #   ]
  #   VCR.use_cassettes(cassettes) do
  #     # make multiple HTTP requests
  #   end
  def use_cassettes(cassette_configs : Array(NamedTuple(name: String, options: Hash(Symbol, String)?)), &)
    if cassette_configs.empty?
      yield
    else
      config = cassette_configs.shift
      use_cassette(config[:name], config[:options] || CassetteOptions.new) do
        use_cassettes(cassette_configs) { yield }
      end
    end
  end

  # Used to configure VCR.
  #
  # @example
  #    VCR.configure do |c|
  #      c.some_config_option = true
  #    end
  #
  # @yield the configuration block
  # @yieldparam config [VCR::Configuration] the configuration object
  # @return [void]
  def configure(&)
    yield configuration
  end

  # @return [VCR::Configuration] the VCR configuration.
  def configuration : Configuration
    config = @@configuration
    if config.nil?
      raise "VCR not initialized. Call VCR.initialize_vcr first."
    end
    config
  end

  # Note: Cucumber integration is not available in Crystal.
  # Use Spectator or minitest.cr with VCR.use_cassette instead.
  # See src/vcr/test_frameworks/spectator.cr for integration helpers.

  # Turns VCR off for the duration of a block.
  #
  # @param (see #turn_off!)
  # @return [void]
  # @raise (see #turn_off!)
  # @see #turn_off!
  # @see #turn_on!
  # @see #turned_on?
  # @see #turned_on
  def turned_off(options = {} of Symbol => Bool, &)
    turn_off!(options)

    begin
      yield
    ensure
      turn_on!
    end
  end

  # Turns VCR off, so that it no longer handles every HTTP request.
  #
  # @param options [Hash] hash of options
  # @option options :ignore_cassettes [Boolean] controls what happens when a cassette is
  #  inserted while VCR is turned off. If `true` is passed, the cassette insertion
  #  will be ignored; otherwise a {VCR::Errors::TurnedOffError} will be raised.
  #
  # @return [void]
  # @raise [VCR::Errors::CassetteInUseError] if there is currently a cassette in use
  # @raise [ArgumentError] if you pass an invalid option
  def turn_off!(options : Hash = {} of Symbol => Bool)
    if cassette = VCR.current_cassette
      raise CassetteInUseError.new("A VCR cassette is currently in use (#{cassette.name}). " +
                                   "You must eject it before you can turn VCR off.")
    end
    @@ignore_cassettes = options.fetch(:ignore_cassettes, false)
    invalid_options = options.keys - [:ignore_cassettes]
    if invalid_options.any?
      raise ArgumentError.new("You passed some invalid options: #{invalid_options.inspect}")
    end
    @@turned_off = true
  end

  # Turns on VCR, for the duration of a block.
  # @param (see #turn_off!)
  # @return [void]
  # @see #turn_off!
  # @see #turned_off
  # @see #turned_on?
  def turned_on(options = {} of Symbol => Bool, &)
    turn_on!

    begin
      yield
    ensure
      turn_off!(options)
    end
  end

  # Turns on VCR, if it has previously been turned off.
  # @return [void]
  # @see #turn_off!
  # @see #turned_off
  # @see #turned_on?
  # @see #turned_on
  def turn_on!
    @@turned_off = false
  end

  # @return whether or not VCR is turned on
  # @note Normally VCR is _always_ turned on; it will only be off if you have
  #  explicitly turned it off.
  # @see #turn_on!
  # @see #turn_off!
  # @see #turned_off
  def turned_on? : Bool
    !@@turned_off
  end

  # @private
  def http_interactions
    cassette = current_cassette
    return cassette.http_interactions if cassette
    VCR::Cassette::HTTPInteractionList::NullList
  end

  # @private
  def real_http_connections_allowed? : Bool
    cassette = current_cassette
    return cassette.recording? if cassette
    !!(configuration.allow_http_connections_when_no_cassette? || !turned_on?)
  end

  # @return [RequestMatcherRegistry] the request matcher registry
  def request_matchers : RequestMatcherRegistry
    matchers = @@request_matchers
    if matchers.nil?
      raise "VCR not initialized. Call VCR.initialize_vcr first."
    end
    matchers
  end

  # @return [Enumerable] list of all cassettes currently being used
  def cassettes : Array(Cassette)
    @@cassettes
  end

  # @private
  def request_ignorer : RequestIgnorer
    ignorer = @@request_ignorer
    if ignorer.nil?
      raise "VCR not initialized. Call VCR.initialize_vcr first."
    end
    ignorer
  end

  # @private
  def library_hooks : LibraryHooks
    hooks = @@library_hooks
    if hooks.nil?
      raise "VCR not initialized. Call VCR.initialize_vcr first."
    end
    hooks
  end

  # @private
  def cassette_serializers : Cassette::Serializers
    serializers = @@cassette_serializers
    if serializers.nil?
      raise "VCR not initialized. Call VCR.initialize_vcr first."
    end
    serializers
  end

  # @private
  def cassette_persisters : Cassette::Persisters
    persisters = @@cassette_persisters
    if persisters.nil?
      raise "VCR not initialized. Call VCR.initialize_vcr first."
    end
    persisters
  end

  # @private
  def record_http_interaction(interaction)
    return unless cassette = current_cassette
    return if VCR.request_ignorer.ignore?(interaction.request)
    cassette.record_http_interaction(interaction)
  end

  # @private
  def fibers_available? : Bool
    true # Crystal has fiber support
  end

  private def ignore_cassettes? : Bool
    @@ignore_cassettes
  end

  private def context_cassettes : Array(Cassette)
    @@cassettes
  end

  # Initialize class variables
  @@turned_off = false
  @@ignore_cassettes = false
  @@cassettes = [] of Cassette
  @@configuration : Configuration? = nil
  @@request_matchers : RequestMatcherRegistry? = nil
  @@request_ignorer : RequestIgnorer? = nil
  @@library_hooks : LibraryHooks? = nil
  @@cassette_serializers : Cassette::Serializers? = nil
  @@cassette_persisters : Cassette::Persisters? = nil

  private def self.initialize_vcr
    @@configuration = Configuration.new
    @@request_matchers = RequestMatcherRegistry.new
    @@request_ignorer = RequestIgnorer.new
    @@library_hooks = LibraryHooks.new
    @@cassette_serializers = Cassette::Serializers.new
    @@cassette_persisters = Cassette::Persisters.new
  end

  initialize_vcr
end
# Removed Ruby-specific middleware and library hooks:
# require "./vcr/middleware/faraday"
# require "./vcr/middleware/rack"
# require "./vcr/test_frameworks/cucumber"
# require "./vcr/test_frameworks/rspec"  # Use spectator.cr instead
# require "./vcr/util/internet_connection"
