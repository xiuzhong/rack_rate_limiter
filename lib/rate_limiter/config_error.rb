#
# Config Error exception class
#
module Rack
  class RateLimiter
    class ConfigError < StandardError; end
  end
end
