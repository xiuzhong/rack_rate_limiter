require 'rack'
require "rate_limiter/version"
require "rate_limiter/sliding_window"
require "rate_limiter/local_cache_rate_limiter"
require "rate_limiter/config_error"
require "rate_limiter/limiter_store"

module Rack
  class RateLimiter
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      accepted, response = LimiterStore.instance.accept_or_respond(request)
      if accepted
        @app.call(env)
      else
        response
      end
    end

    class << self
      def limit_on(*args, &block)
        LimiterStore.instance.limit_on(*args, &block)
      end
    end
  end
end
