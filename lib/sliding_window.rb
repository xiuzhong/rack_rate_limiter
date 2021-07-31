# RateLimiter::SlidingWindow
#
# - An fixed-size Array is used to store timestamps within window
# - To avoid array elements shift, use head and bottom pointer to track the latest and eldest
# - time window precision is at second
#
module RateLimiter
  class SlidingWindow
    # Initialization
    #
    # @param window_size [Integer] seconds of the sliding window
    # @param rate_limit [Integer] how many calls at max are allowed in the window size
    def initialize(window_size:, rate_limit:)
      @window_size = window_size
      @rate_limit = rate_limit
      @queue = Array.new(@rate_limit)
      @head = nil   # index of @queue pointing to the latest timestamp, nil if no timestamp
      @bottom = nil # index of @queue pointing to the eldest timestamp, nil if no timestamp
      @semaphore = Mutex.new
    end

    def allow?
      current = Time.now.to_i
      @semaphore.synchronize do
        remove_expired(current - window_size)
        return false if is_full?

        add_current(current)
      end
      true
    end

    private

    attr_reader :window_size, :rate_limit, :queue, :head, :bottom

    def remove_expired(expired_at)
      return if bottom.nil?

      index = bottom
      while queue[index] && queue[index] <= expired_at do
        queue[index] = nil
        index = next_index(index)
      end
      @bottom = queue[index].nil? ? nil : index
      @head = nil if head && queue[head].nil?
    end

    def add_current(now_second)
      @head = head.nil? ? 0 : next_index(head)
      queue[head] = now_second
      @bottom ||= head
    end

    def is_full?
      head && next_index(head) == bottom
    end

    def next_index(current)
      (current + 1) % rate_limit
    end
  end
end
