RSpec.describe Rack::RateLimiter::SlidingWindow do
  subject(:sliding_window) do
    described_class.new(window_size: window_size, rate_limit: rate_limit)
  end

  context 'single thread env' do
    shared_examples 'calls in 10 seconds' do |limit|
      context "#{limit} calls in 10 seconds" do
        let(:window_size) { 10 }
        let(:rate_limit) { limit }

        it "allows calls within limit, and denies the call out of the limit" do
          limit.times { expect(sliding_window.allow?).to be_truthy }
          expect(sliding_window.allow?).to be_falsy
        end

        it "allows the call after 10s" do
          limit.times { expect(sliding_window.allow?).to be_truthy }
          Timecop.travel(Time.now + 10) do
            limit.times { expect(sliding_window.allow?).to be_truthy }
          end
        end
      end
    end
    include_examples 'calls in 10 seconds', 1
    include_examples 'calls in 10 seconds', 2
    include_examples 'calls in 10 seconds', 20

    describe 'the limit is sliding' do
      let(:window_size) { 10 }
      let(:rate_limit) { 2 }

      it 'adopts sliding window, instead of fixed time box' do
        expect(sliding_window.allow?).to be_truthy
        Timecop.travel(Time.now + window_size / 2) { expect(sliding_window.allow?).to be_truthy }
        Timecop.travel(Time.now + window_size) do
          expect(sliding_window.allow?).to be_truthy
          expect(sliding_window.allow?).to be_falsy
        end
        Timecop.travel(Time.now + window_size * 1.5) do
          expect(sliding_window.allow?).to be_truthy
        end
      end
    end
  end

  context 'multiple threads env' do
    def run_test_in_threads(number_of_threads, &test)
      threads = []
      number_of_threads.times do
        threads << Thread.new { test.call }
      end
      threads.map do |t|
        t.join
        t.value
      end.flatten
    end

    shared_examples 'mutli-threads calls in 10 seconds' do |limit|
      context "#{limit} calls in 10 seconds" do
        let(:window_size) { 10 }
        let(:rate_limit) { limit }
        let(:threads_number) { limit * 10 }

        it "allows calls within limit, and denies the call out of the limit" do
          result = run_test_in_threads(threads_number) { (1..limit).to_a.map { sliding_window.allow? } }
          expect(result.select(&:itself).size).to eq(limit)
        end

        it "allows the call after 10s" do
          result = run_test_in_threads(threads_number) { (1..limit).to_a.map { sliding_window.allow? } }
          expect(result.select(&:itself).size).to eq(limit)

          Timecop.travel(Time.now + 10) do
            result = run_test_in_threads(threads_number) { (1..limit).to_a.map { sliding_window.allow? } }
            expect(result.select(&:itself).size).to eq(limit)
          end
        end
      end
    end

    include_examples 'mutli-threads calls in 10 seconds', 1
    include_examples 'mutli-threads calls in 10 seconds', 2
    include_examples 'mutli-threads calls in 10 seconds', 20
  end
end
