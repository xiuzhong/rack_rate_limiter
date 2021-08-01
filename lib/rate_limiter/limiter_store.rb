require 'singleton'

module Rack
  class RateLimiter
    class LimiterStore
      include Singleton

      # The RateLimiter support multiple rate limiters with its own window_size, rate_limit
      #   and creteria, the creteria decides how RateLimiter enforce the limit on request,
      #   e.g per IP, per API token etc.
      #
      # @param [String] label Name of this limiter
      # @param [Hash] options The options of the limiter
      # @option options [Integer] :window_size number of seconds of the rate limit window
      # @option options [Integer] :rate_limit number of requests allowed with the window
      #
      # for block { |request| ... }
      # @yield [request] Callback to produce the creteria from Rack request
      # @yieldparam [Rack::Request] request The Rack request
      # @yieldreturn [String] the creteria
      def limit_on(label, options, &block)
        raise(ConfigError, 'creteria callback is missing') if block.nil?
        raise(ConfigError, 'label is missing') if label.nil? || label.strip.empty?
        raise(ConfigError, 'duplicated label') if limiters.has_key?(label)

        unless valid_options?(options)
          raise ConfigError, 'invalid or missing :window_size and/or rate_limit'
        end

        limiter = @limiter_type.new(
          # JRuby doesn't support Hash slice() yet
          window_size: options[:window_size], rate_limit: options[:rate_limit]
        )

        limiters[label] = Limiter.new(label, block, limiter)
      end

      # Check if the request is accepted, respond if it's not
      #
      # @param [Rack::Request] request
      # @return [Boolean, [status, header, body]] accpeted, response
      # - if it's accepted, return true, nil
      # - if it's not,      return false, response
      def accept_or_respond(request)
        @limiters.each do |_label, limiter|
          return false, response_on_deny(request, limiter) unless limiter.allow?(request)
        end

        return true, nil
      end

      private

      def response_on_deny(request, limiter)
        [
          429,
          { 'Content-Type' => 'text/plain' },
          ["Rate limit exceeded. Try again in #{limiter.window_size} seconds"]
        ]
      end

      attr_reader :limiters

      class Limiter < Struct.new(:label, :callback, :limiter)
        def allow?(request)
          creteria = callback.call(request)
          return true if creteria.nil? || creteria.to_s.strip.empty?
          limiter.allow?(creteria)
        end

        def window_size
          limiter.window_size
        end
      end

      def initialize
        @limiters = {}
        # TODO add support of other types of RateLimiter
        @limiter_type = LocalCacheRateLimiter
      end

      def valid_options?(options)
        options[:window_size].to_i > 0 && options[:rate_limit].to_i > 0
      end
    end
  end
end
