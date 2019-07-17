# frozen_string_literal: true

require 'dry/effects/provider'
require 'dry/effects/instructions/raise'

module Dry
  module Effects
    module Providers
      class Env < Provider[:env]
        include Dry::Equalizer(:values, :dynamic)

        Locate = Effect.new(type: :env, name: :locate)

        param :values, default: -> { EMPTY_HASH }

        attr_reader :parent

        def read(key)
          parent.fetch(key) { fetch(key) }
        end

        protected \
        def fetch(key)
          values.fetch(key) do
            if key.is_a?(::String) && ::ENV.key?(key)
              ::ENV[key]
            elsif block_given?
              yield
            else
              Instructions.Raise(::KeyError.new(key))
            end
          end
        end

        def locate
          self
        end

        def call(stack, values = EMPTY_HASH, options = EMPTY_HASH)
          unless values.empty?
            @values = @values.merge(values)
          end

          if options.fetch(:overridable, false)
            @parent = ::Dry::Effects.yield(Locate) { EMPTY_HASH }
          else
            @parent = EMPTY_HASH
          end

          super(stack)
        end

        def provide?(effect)
          if super
            !effect.name.equal?(:read) || key?(effect.payload[0])
          else
            false
          end
        end

        def key?(key)
          values.key?(key) || key.is_a?(::String) && ::ENV.key?(key) || parent.key?(key)
        end
      end
    end
  end
end
