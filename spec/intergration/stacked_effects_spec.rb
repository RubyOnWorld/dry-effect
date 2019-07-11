# frozen_string_literal: true

RSpec.describe 'stacked effects' do
  context 'different effect types' do
    include Dry::Effects.Random
    include Dry::Effects.CurrentTime

    let(:rand_handler) { make_handler(:random) }

    let(:time_handler) { make_handler(:current_time) }

    example 'nesting handlers' do
      past = Time.now
      future = rand_handler.() do
        time_handler.() do
          current_time + rand(100)
        end
      end

      expect(future).to be_between(past, past + 101)
    end
  end

  context 'same types' do
    context 'different identifier' do
      before do
        extend Dry::Effects.State(:counter_a), Dry::Effects.State(:counter_b)
      end

      let(:state_a) { make_handler(:state, :counter_a) }

      let(:state_b) { make_handler(:state, :counter_b) }

      example 'works nicely' do
        accumulated_state = state_a.(0) do
          state_b.(10) do
            self.counter_a += 4
            self.counter_b = counter_a + 20
            :result
          end
        end

        expect(accumulated_state).to eql([4, [24, :result]])
      end
    end

    context 'same identifier' do
      before do
        extend Dry::Effects.State(:counter)
        extend Dry::Effects::Handler.State(:counter)
      end

      example do
        accumulated_state = handle_state(0) do
          self.counter += 1
          handle_state(10) do
            self.counter += 30
            :result
          ensure
            self.counter += 50
          end
        ensure
          self.counter += 4
        end

        expect(accumulated_state).to eql([5, [90, :result]])
      end
    end
  end

  context 'mixing two stack-affecting effects' do
    before do
      extend Dry::Effects.Amb(:feature)
      extend Dry::Effects.Interrupt(:stop)
      extend Dry::Effects::Handler.Amb(:feature, as: :handle_feature)
      extend Dry::Effects::Handler.Interrupt(:stop, as: :handle_stop)
    end

    example 'amb,interrupt' do
      expect(handle_feature { handle_stop { stop(feature?) } }).to eql([false, true])
    end

    example 'interrupt,amb' do
      expect(handle_stop { handle_feature { stop(feature?) } }).to eql(false)
    end

    context 'more nesting' do
      before do
        extend Dry::Effects.Amb(:feature2)
        extend Dry::Effects::Handler.Amb(:feature2, as: :handle_feature2)
      end

      example 'interrupt,amb' do
        expect(handle_feature { handle_feature2 { [feature?, feature2?] } }).to eql([
          [[false, false], [false, true]], [[true, false], [true, true]]
        ])
      end
    end
  end

  context 'defer + parallel' do
    before do
      extend Dry::Effects.Defer
      extend Dry::Effects.Parallel
      extend Dry::Effects::Handler.Parallel
      extend Dry::Effects::Handler.Defer
    end

    example 'defer : parallel' do
      tasks = [0, 1, 2]
      observed_order = []
      result = handle_defer do
        handle_parallel do
          pars = tasks.map do |i|
            defer do
              par do
                sleep((tasks.size - i) / 20.0)
                observed_order << i
                i
              end
            end
          end

          wait(join(pars))
        end
      end

      expect(result).to eql([0, 1, 2])
      expect(observed_order).to eql([2, 1, 0])
    end

    example 'parallel : defer' do
      tasks = [0, 1, 2]
      observed_order = []
      result = handle_parallel do
        handle_defer do
          pars = tasks.map do |i|
            defer do
              par do
                sleep((tasks.size - i) / 20.0)
                observed_order << i
                i
              end
            end
          end

          wait(join(pars))
        end
      end

      expect(result).to eql([0, 1, 2])
      expect(observed_order).to eql([2, 1, 0])
    end
  end

  context 'async + state' do
    include Dry::Effects.Async
    include Dry::Effects::Handler.Async
    include Dry::Effects.State(:counter)
    include Dry::Effects::Handler.State(:counter)

    let(:outputs) { [] }

    def program
      tasks = Array.new(3) do
        async do
          self.counter += 10
          outputs << counter
        end
      end

      tasks.each { |t| await(t) }
    end

    example 'async : state' do
      result = handle_async { handle_state(100) { program } }
      expect(outputs).to eql([110, 120, 130])
      expect(result).to be_nil
    end

    example 'state : async' do
      result = handle_state(100) { handle_async { program } }
      expect(outputs).to eql([110, 120, 130])
      expect(result).to eql([130, nil])
    end
  end

  context 'cache + state' do
    include Dry::Effects::Handler.State(:counter)
    include Dry::Effects::Handler.Cache(:counter_values)
    include Dry::Effects.State(:counter)
    include Dry::Effects.Cache(:counter_values)

    example 'cache : state' do
      calls = 0

      result = handle_cache do
        Array.new(2) do |i|
          handle_state(0) do
            Array.new(3) do
              counter_values(i) do
                calls += 1
                counter
              end
            end

            self.counter += 1
          end
        end
      end

      expect(calls).to eql(2)
      expect(result).to eql([[1, 1], [1, 1]])
    end
  end

  context 'state + reader' do
    include Dry::Effects::Handler.State(:value, as: :handle_state)
    include Dry::Effects::Handler.Reader(:value, as: :handle_reader)
    include Dry::Effects.State(:value)

    it 'works according to stack rules' do
      handled = handle_state(0) do
        handle_reader(5) do
          self.value = value + 10
          value
        end
      end

      expect(handled).to eql([15, 5])
    end
  end
end
