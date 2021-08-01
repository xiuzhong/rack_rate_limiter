# RateLimiter::LocalCacheStore
#
module Rack
  class RateLimiter
    class LocalCacheRateLimiter
      attr_reader :window_size, :rate_limit

      # Initialization
      #
      # @param window_size [Integer] seconds of the sliding window
      # @param rate_limit [Integer] how many calls at max are allowed in the window size
      def initialize(window_size:, rate_limit:)
        @store = {}
        @window_size = window_size
        @rate_limit = rate_limit
        @semaphore = Mutex.new
      end

      def allow?(key)
        window = @semaphore.synchronize do
          @store[key] ||= SlidingWindow.new(window_size: window_size, rate_limit: rate_limit)
        end
        window.allow?
      end
    end
  end
end
