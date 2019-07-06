# frozen_string_literal: true

require 'dry/effects/providers/reader'

module Dry
  module Effects
    module Providers
      class State < Reader[:state]
        def write(value)
          @state = value
        end

        def call(stack, state)
          r = super(stack, state)
          [@state, r]
        end

        def provide?(effect)
          super && scope.equal?(effect.scope)
        end
      end
    end
  end
end
