# frozen_string_literal: true

source 'https://rubygems.org'

eval_gemfile 'Gemfile.devtools'

gemspec

group :test do
  gem 'dry-auto_inject', require: false
  gem 'dry-system', github: 'dry-rb/dry-system', branch: 'master', require: false
  gem 'warning'
end

group :tools do
  gem 'pry-byebug', platform: :mri
end

gem 'dry-struct'
gem 'dry-monads'
