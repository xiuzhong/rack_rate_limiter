require 'rack/mock'

RSpec.describe Rack::RateLimiter do
  describe "configuration by #limit_on" do
    context 'valid configuration' do
      it 'does not raise error' do
        expect do
          described_class.limit_on('test', window_size: 10, rate_limit: 10) do |req|
            req.ip
          end
        end.not_to raise_error
      end
    end

    context 'invalid label configuration' do
      it 'raise on label' do
        [nil, '', '   '].each do |label|
          expect do
            described_class.limit_on(label, window_size: 10, rate_limit: 10) do |req|
              req.ip
            end
          end.to raise_error /label/
        end
      end

      it 'raise on duplicate label' do
        expect do
          2.times do
            described_class.limit_on('label', window_size: 10, rate_limit: 10) do |req|
              req.ip
            end
          end
        end.to raise_error /duplicated/
      end
    end

    context 'invalid options configuration' do
      it 'raise on window_size' do
        expect do
          described_class.limit_on('label_1', rate_limit: 10) do |req|
            req.ip
          end
        end.to raise_error /window_size/
      end

      it 'raise on rate_limit' do
        expect do
          described_class.limit_on('label_2', window_size: 10) do |req|
            req.ip
          end
        end.to raise_error /rate_limit/
      end
    end

    context 'missing callback' do
      it 'raise on callback' do
        expect do
          described_class.limit_on('label_1', rate_limit: 10)
        end.to raise_error /callback/
      end
    end
  end
end
