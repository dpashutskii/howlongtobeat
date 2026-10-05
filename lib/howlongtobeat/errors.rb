module HowLongToBeat
  class Error < StandardError; end

  # HLTB answered 429. Back off; don't retry right away.
  class RateLimitedError < Error; end

  # Network failure, timeout, or an HTTP status that means "try later"
  # (5xx, 403, unexpected redirects). Never means "not found".
  class RequestError < Error; end

  # HLTB answered, but not in the shape we know. Usually a site change.
  class ParseError < Error; end
end
