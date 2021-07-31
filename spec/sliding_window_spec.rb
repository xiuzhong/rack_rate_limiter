RSpec.describe RateLimiter::SlidingWindow do
  subject(:sliding_window) do
    described_class.new(window_size: window_size, rate_limit: rate_limit)
  end

  context 'single thread env' do
    shared_examples 'calls in 10 seconds' do |n|
      context "#{n} calls in 10 seconds" do
        let(:window_size) { 10 }
        let(:rate_limit) { n }

        it "allows calls within limit, and denies the call out of the limit" do
          n.times { expect(sliding_window.allow?).to be_truthy }
          expect(sliding_window.allow?).to be_falsy
        end

        it "allows the call after 10s" do
          n.times { expect(sliding_window.allow?).to be_truthy }
          Timecop.travel(Time.now + 10) do
            n.times { expect(sliding_window.allow?).to be_truthy }
          end
        end
      end
    end
    include_examples 'calls in 10 seconds', 1
    include_examples 'calls in 10 seconds', 2
    include_examples 'calls in 10 seconds', 20
  end
end
