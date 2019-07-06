# frozen_string_literal: true

require 'dry/effects/handler'

RSpec.describe 'handling cache' do
  include Dry::Effects::Handler.Cache(:cached)
  include Dry::Effects.Cache(:cached)

  example 'fetching cached values' do
    result = handle_cache do
      [
        cached([1, 2, 3]) { :foo },
        cached([1, 2, 3]) { :bar }
      ]
    end

    expect(result).to eql(%i[foo foo])
  end
end
