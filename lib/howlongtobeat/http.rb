require 'net/http'
require 'openssl'
require 'uri'

module HowLongToBeat
  # Paced HTTP transport for HLTB. Every request waits until at least
  # `min_interval` seconds have passed since the previous one, however the
  # caller loops. 2xx and 404 come back as a Response; 429 raises
  # RateLimitedError; anything else raises RequestError, so a failure can
  # never look like "not found".
  class Http
    Response = Struct.new(:code, :body)

    USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' \
                 '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36'
    BASE_URL = 'https://howlongtobeat.com'

    NETWORK_ERRORS = [
      Timeout::Error, IOError, EOFError, SocketError, SystemCallError,
      OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError
    ].freeze

    def initialize(min_interval: 2.0, open_timeout: 5, read_timeout: 10,
                   clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                   sleeper: ->(seconds) { sleep(seconds) })
      @min_interval = min_interval
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @clock = clock
      @sleeper = sleeper
      @mutex = Mutex.new
      @last_request_at = nil
    end

    def get(url, headers = {})
      uri = URI(url)
      perform(uri, Net::HTTP::Get.new(uri.request_uri, default_headers.merge(headers)))
    end

    def post(url, headers, body)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri.request_uri, default_headers.merge(headers))
      request.body = body
      perform(uri, request)
    end

    private

    def perform(uri, request)
      pace!
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                     open_timeout: @open_timeout,
                                                     read_timeout: @read_timeout) do |connection|
        connection.request(request)
      end
      to_response(uri, response)
    rescue *NETWORK_ERRORS => e
      raise RequestError, "#{request.method} #{uri.path} failed: #{e.class}: #{e.message}"
    end

    def to_response(uri, response)
      code = response.code.to_i
      raise RateLimitedError, "HLTB rate limited #{uri.path} (429)" if code == 429
      return Response.new(code, response.body.to_s) if (200..299).cover?(code) || code == 404

      raise RequestError, "HLTB returned #{code} for #{uri.path}"
    end

    def pace!
      @mutex.synchronize do
        if @last_request_at
          wait = @min_interval - (@clock.call - @last_request_at)
          @sleeper.call(wait) if wait.positive?
        end
        @last_request_at = @clock.call
      end
    end

    def default_headers
      { 'User-Agent' => USER_AGENT, 'Referer' => BASE_URL, 'Origin' => BASE_URL, 'Accept' => '*/*' }
    end
  end
end
