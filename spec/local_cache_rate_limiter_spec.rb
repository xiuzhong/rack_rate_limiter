RSpec.describe RateLimiter::LocalCacheRateLimiter do
  subject(:rate_limiter) do
    described_class.new(window_size: window_size, rate_limit: rate_limit)
  end

  context 'single thread env' do

    context "one call is allowed 10 seconds per key" do
      let(:window_size) { 10 }
      let(:rate_limit) { 1 }
      let(:key_1) { 'key_1' }
      let(:key_2) { 'key_2' }

      it "enforce limits as per key respectively" do
        expect(rate_limiter.allow?(key_1)).to be_truthy
        expect(rate_limiter.allow?(key_1)).to be_falsy
        expect(rate_limiter.allow?(key_2)).to be_truthy
        expect(rate_limiter.allow?(key_2)).to be_falsy
      end
    end
  end

  context 'multiple threads env' do
    def run_test_in_threads(number_of_threads, &test)
      threads = []
      number_of_threads.times do
        threads << Thread.new { test.call }
      end

      results = threads.map do |t|
        t.join
        t.value
      end

      results.each_with_object({}) do |result, hash|
        result.each do |key, success|
          hash[key] ||= 0
          hash[key] += 1 if success
        end
      end
    end

    def tests_run_with_one_thread
      # each thread calls against each key in keys
      # result of each thread run would like: { 'key_1' => true, 'key_2' => false, ... }
      keys.each_with_object({}) do |key, hash|
        hash[key] = rate_limiter.allow?(key)
      end
    end

    shared_examples 'mutli-threads calls in 10 seconds' do |limit|
      let(:keys) { (1..10).to_a.map { |i| "key_#{i}" } }

      context "#{limit} calls in 10 seconds" do
        let(:window_size) { 10 }
        let(:rate_limit) { limit }
        let(:threads_number) { limit * 10 }

        it "allows/denies calls of keys respectively" do
          result = run_test_in_threads(threads_number) do
            tests_run_with_one_thread
          end

          expect(result.size).to eq keys.size
          expect(result.keys.uniq).to contain_exactly(*keys)
          expect(result.values.uniq).to contain_exactly(limit)
        end

        it "allows/denies calls of keys respectively beyond one time window" do
          2.times do |i|
            Timecop.travel(Time.now + 10 * i) do
              result = run_test_in_threads(threads_number) do
                tests_run_with_one_thread
              end

              expect(result.size).to eq keys.size
              expect(result.keys.uniq).to contain_exactly(*keys)
              expect(result.values.uniq).to contain_exactly(limit)
            end
          end
        end
      end
    end

    include_examples 'mutli-threads calls in 10 seconds', 1
    include_examples 'mutli-threads calls in 10 seconds', 2
    include_examples 'mutli-threads calls in 10 seconds', 20
  end
end
