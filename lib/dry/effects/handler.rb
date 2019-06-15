require 'fiber'
require 'dry/effects/initializer'
require 'dry/effects/effect'
require 'dry/effects/errors'
require 'dry/effects/stack'

module Dry
  module Effects
    class Handler
      FORK = ::Object.new.freeze

      extend Initializer

      param :provider_type, default: -> { Undefined }

      param :identifier, default: -> { Undefined }

      def call(initial = Undefined, &block)
        if Undefined.equal?(initial)
          provider = provider_type.new(identifier: identifier)
        else
          provider = provider_type.new(initial, identifier: identifier)
        end

        stack = Stack.current

        if stack.empty?
          stack.push(provider) { spawn_fiber(stack, &block) }
        else
          stack.push(provider, &block)
        end
      end

      def spawn_fiber(stack, &block)
        fiber = ::Fiber.new(&block)
        result = fiber.resume

        loop do
          break result unless fiber.alive?

          provided = stack.(result) do
            if FORK.equal?(result)
              lambda do |&cont|
                copy = stack.dup
                Stack.use(copy) { spawn_fiber(copy, &cont) }
              end
            else
              ::Dry::Effects.yield(result)
            end
          end

          result = fiber.resume(provided)
        end
      end
    end
  end
end
