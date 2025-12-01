module VCR
  # @private
  module Hooks
    # @private
    class FilteredHook
      # All hooks take interaction and optional cassette
      getter hook : Proc(HTTPInteraction::HookAware, Cassette?, Nil)
      getter filters : Array(Proc(HTTPInteraction::HookAware, Bool))

      def initialize(@hook, @filters)
      end

      def conditionally_invoke(interaction : HTTPInteraction::HookAware, cassette : Cassette? = nil)
        # Check all filters - if any filter returns false, don't invoke the hook
        filters.each do |filter|
          return unless filter.call(interaction)
        end

        # Invoke the hook
        hook.call(interaction, cassette)
      end
    end

    # Storage for hooks
    @hooks : Hash(Symbol, Array(FilteredHook))?

    def hooks : Hash(Symbol, Array(FilteredHook))
      @hooks ||= {} of Symbol => Array(FilteredHook)
    end

    def invoke_hook(hook_type : Symbol, interaction : HTTPInteraction::HookAware, cassette : Cassette? = nil)
      return [] of Nil unless hooks.has_key?(hook_type)
      hooks[hook_type].map do |hook|
        hook.conditionally_invoke(interaction, cassette)
      end
    end

    def clear_hooks
      hooks.clear
    end

    def has_hooks_for?(hook_type : Symbol) : Bool
      hooks.has_key?(hook_type) && hooks[hook_type].any?
    end

    # Define a hook with the given type
    # @param hook_type [Symbol] The type of hook (e.g., :before_record, :before_playback)
    # @param tag [Symbol, nil] Optional tag to filter when the hook should run
    # @param prepend [Bool] Whether to prepend the hook (run first) or append (run last)
    # @param block [Proc] The hook implementation
    def define_hook_impl(hook_type : Symbol, tag : Symbol? = nil, prepend : Bool = false, &block : HTTPInteraction::HookAware, Cassette? -> Nil)
      hooks[hook_type] ||= [] of FilteredHook

      filters = [] of Proc(HTTPInteraction::HookAware, Bool)
      if tag
        # Create a filter that checks if the cassette has the specified tag
        tag_filter = ->(interaction : HTTPInteraction::HookAware) {
          # For now, always pass tag filter - proper implementation would check cassette tags
          true
        }
        filters << tag_filter
      end

      filtered_hook = FilteredHook.new(block, filters)

      if prepend
        hooks[hook_type].unshift(filtered_hook)
      else
        hooks[hook_type] << filtered_hook
      end
    end

    # Macro to define hook methods at compile time
    # This replaces Ruby's dynamic define_method approach
    macro define_hook(hook_type, prepend = false)
      def {{hook_type.id}}(tag : Symbol? = nil, &block : HTTPInteraction::HookAware, Cassette? -> Nil)
        define_hook_impl({{hook_type}}, tag, {{prepend}}, &block)
      end

      def {{hook_type.id}}(tag : Symbol? = nil, &block : HTTPInteraction::HookAware -> Nil)
        # Wrapper for blocks that don't take cassette parameter
        wrapped_block = ->(interaction : HTTPInteraction::HookAware, _cassette : Cassette?) {
          block.call(interaction)
          nil
        }
        define_hook_impl({{hook_type}}, tag, {{prepend}}, &wrapped_block)
      end
    end
  end
end
