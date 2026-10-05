module HowLongToBeat
  class Error < StandardError; end

  # HLTB answered 429. Back off; don't retry right away.
  class RateLimitedError < Error; end

  # Network failure, timeout, or an HTTP status that means "try later"
  # (5xx, 403, unexpected redirects). Never means "not found".
  # `status` is the HTTP status when there was one, nil for network failures.
  class RequestError < Error
    attr_reader :status

    def initialize(message = nil, status: nil)
      super(message)
      @status = status
    end
  end

  # HLTB answered, but not in the shape we know. Usually a site change.
  class ParseError < Error; end
end
