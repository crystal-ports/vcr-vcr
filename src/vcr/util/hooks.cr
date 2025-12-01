module VCR
  # @private
  module Hooks
    # @private
    class FilteredHook
      # All hooks take interaction and optional cassette
      getter hook : Proc(HTTPInteraction::HookAware, Cassette?, Nil)
      getter tag : Symbol?

      def initialize(@hook, @tag)
      end

      def conditionally_invoke(interaction : HTTPInteraction::HookAware, cassette : Cassette? = nil)
        # Check tag filter - if tag is specified, cassette must have that tag
        if t = @tag
          if c = cassette
            if tags = c.tags
              return unless tags.includes?(t)
            else
              return # No tags on cassette, skip this tagged hook
            end
          else
            return # No cassette, skip this tagged hook
          end
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

    # Overload for hooks that don't require an interaction (e.g., after_library_hooks_loaded)
    def invoke_hook(hook_type : Symbol)
      # These hooks have no interaction - they're lifecycle events
      # We don't actually call the hooks since there's no interaction to pass
      # This is mainly used for after_library_hooks_loaded which is a no-op in Crystal
      nil
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

      filtered_hook = FilteredHook.new(block, tag)

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
