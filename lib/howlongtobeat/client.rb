module HowLongToBeat
  # Polite, stateful HLTB client. Keep one instance per process: it remembers
  # the discovered search endpoint and the auth token, and its Http enforces
  # a minimum gap between requests.
  class Client
    BASE_URL = Http::BASE_URL

    def initialize(http: Http.new, endpoint_ttl: 3600, token_ttl: 60, token_warmup: 1.2,
                   clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                   sleeper: ->(seconds) { sleep(seconds) })
      @http = http
      @endpoint_ttl = endpoint_ttl
      @token_ttl = token_ttl
      @token_warmup = token_warmup
      @clock = clock
      @sleeper = sleeper
      @endpoint = nil
      @token = nil
    end

    # One GET of the game page. nil when HLTB has no such game (404).
    def game(id)
      response = @http.get("#{BASE_URL}/game/#{Integer(id)}")
      return nil if response.code == 404

      GamePageParser.parse(response.body)
    end
  end
end
