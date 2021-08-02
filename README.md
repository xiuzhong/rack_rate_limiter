# RateLimiter

Rack middleware that keeps track of requests and limits it such that a requester can only make limited requests in given period.
After the limit has been reached, return a 429 with the text "Rate limit exceeded. Try again in xxx seconds".

## Configuration
RateLimiter should be configured properly before it's inserted into Rack. It can be configured as:
```
RateLimit.limit_on(label, options, &callback)
```
The RateLimiter support more than one rate limiter which has its own window_size, rate_limit, and creteria. The creteria decides how RateLimiter enforce the limit on request, e.g per IP, per API token etc.
When multiple limiting creteria are configured, exceeding limit on any creteria will block the request and lead to 429 response.

- label: String, name of the creteria, unique
- options: Hash
  - window_size: Integer, the time period in seconds
  - rate_limit:  Integer, number of requests allowed in given time period
- callback: method to produce the key from Rack::Request (see example below)

E.g.
```
  Rack::RateLimiter.limit_on('source_ip', window_size: 10, rate_limit: 1) do |req|
    req.ip
  end

  Rack::RateLimiter.limit_on('api_token', window_size: 10, rate_limit: 1) do |req|
    req.get_header('x-api-key')
  end
```
For __rails__ application, this should be done in `config/initializers`

## Usage
a) For __rails__ applications, following the [Rails guide](https://guides.rubyonrails.org/rails_on_rack.html#adding-a-middleware)

E.g.
```ruby
config.middleware.insert_after(Rack::XxxxxXxxxx, Rack::RateLimiter)
```

b) For __rack__ applications:

```ruby
# In config.ru

require "rate_limiter"
use Rack::RateLimiter
```
## Run test/spec
```
# git clone the repo, and cd into the repo directory
# The implementation use JRuby (see Design for details)
#   if it's not available to you, please update `.ruby-version` to your favorite ruby version.
> bundle install
> rake spec
```

## Design & Note of the implementation
- This RateLimiter is designed for multi-threaded web application (like Puma), because it uses in-memory cache to track request's timestamp.
- Hence it doesn't apply to process fork based web server like Passenger. It doesn't support distributed web server either.
- Major classes:
  - Rack::RateLimiter: Rack middleware implementation
  - Rack::RateLimiter::LimiterStore: A singleton object keeping all active rate limiters (e.g by IP, by api token etc)
  - Rack::RateLimiter::LocalCacheRateLimiter: An in-memory implementation of a rate limiter, which keeps all active sliding windows
  - Rack::RateLimiter::SlidingWindow: A sliding window of one particular criteria (e.g. one IP or one API token)
- It implements a [Sliding window](https://cloud.google.com/architecture/rate-limiting-strategies-techniques#techniques-enforcing-rate-limits) to track the request timestamp, and enforce the rate limit. The sliding window data structure is designed as circular array to avoid data shifting. The tradeoff of this design is it takes a lot memory when rate limit is large (say 50000 per day), to acheive a linear time complexity.
- Ruby MRI doesn't support real parallelism because of GIL, the multi-threaded test cases can't be failed on Ruby MRI. So I developed and tested on JRuby to make sure it works in real parallel multi-threaded env. Of course, it works on Ruby MRI perfectly.

## TODO
Because of the time, I haven't finished all necessary functions to make it production-ready. There are some critical TODOs:
- Clear the stale sliding window. Because it creates a sliding window object for each distinct creteria (e.g. per IP). Over time it keeps a big bunch of sliding window objects, some of them are not used any longer (because the client doesn't request any more). These stale objects should be cleared regularly so the memory will not be throttled. This can be implemented as periodical task triggered by incoming request.
- Add logging. So the RateLimiter can log out some important information, or debug information to configurable logger for operational or debug purpose.
- Currently it supports `LocalCacheRateLimiter` only which limits the usage to one process only. By implementing other type of RateLimiter, it can be extended to support broader use cases. E.g. By using Redis to track the timestamps, it can support multi-processes and distributed applications

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rate_limiter'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rate_limiter

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
