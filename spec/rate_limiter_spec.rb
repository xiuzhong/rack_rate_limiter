require 'rack/mock'
require 'rack/test'

RSpec.describe Rack::RateLimiter do
  it "has a version number" do
    expect(RateLimiter::VERSION).not_to be nil
  end

  describe "application call" do
    include Rack::Test::Methods

    def mock_app
      main_app = lambda { |env|
        request = Rack::Request.new(env)
        headers = {'Content-Type' => "text/html"}
        headers['Set-Cookie'] = "id=1; path=/\ntoken=abc; path=/; secure; HttpOnly"
        [200, headers, ['Hello world!']]
      }

      builder = Rack::Builder.new
      builder.use Rack::RateLimiter
      builder.run main_app
      Rack::Lint.new(builder.to_app)
    end

    def run_test_in_threads(number_of_threads, &test)
      threads = []
      number_of_threads.times do |i|
        threads << Thread.new { test.call(i) }
      end

      threads.map do |t|
        t.join
        t.value
      end.flatten
    end

    before(:all) do
      Rack::RateLimiter.limit_on('main', window_size: 10, rate_limit: 1) do |req|
        req.ip
      end

      Rack::RateLimiter.limit_on('token', window_size: 10, rate_limit: 1) do |req|
        req.get_header('x-api-key')
      end
    end

    let(:url) { 'http://example.com' }
    let!(:app) { mock_app }

    context 'single rate limit creteria' do
      it 'enforces the rate limit' do
        get url, {}, { 'REMOTE_ADDR' => '127.0.0.1' }
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq 'Hello world!'

        get url, {}, { 'REMOTE_ADDR' => '127.0.0.1' }
        expect(last_response.status).to eq 429
        expect(last_response.body).to eq 'Rate limit exceeded. Try again in 10 seconds'
      end

      it 'enforces the rate limit respectively' do
        get url, {}, { 'REMOTE_ADDR' => '1.0.0.1' }
        expect(last_response.status).to eq 200
        get url, {}, { 'REMOTE_ADDR' => '1.0.0.2' }
        expect(last_response.status).to eq 200
      end
    end

    context 'multiple rate limit creterias' do
      it 'denis if any of creterias is violated' do
        get url, {}, { 'REMOTE_ADDR' => '2.0.0.1', 'x-api-key' => 'token_1' }
        expect(last_response.status).to eq 200
        get url, {}, { 'REMOTE_ADDR' => '2.0.0.2', 'x-api-key' => 'token_1' }
        expect(last_response.status).to eq 429
      end
    end
  end
end
