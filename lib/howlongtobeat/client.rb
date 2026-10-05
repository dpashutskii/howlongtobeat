require 'json'
require 'nokogiri'

module HowLongToBeat
  # Polite, stateful HLTB client. Keep one instance per process: it remembers
  # the discovered search endpoint and the auth token, and its Http enforces
  # a minimum gap between requests.
  class Client
    BASE_URL = Http::BASE_URL

    # Tried in order only when no script chunk reveals the search endpoint.
    KNOWN_SEARCH_PATHS = %w[/api/search/site /api/bleed /api/finder /api/search /api/s].freeze

    Endpoint = Struct.new(:path, :search_info, :found_at)
    Token = Struct.new(:auth, :issued_at)
    EndpointGone = Class.new(StandardError)
    private_constant :Endpoint, :Token, :EndpointGone

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

    # Raw candidates for a title. [] is a genuine "not on HLTB".
    def search(title, modifier: HTMLRequests::SearchModifiers::NONE)
      SearchResultParser.parse(search_json(title, modifier: modifier))
    end

    # The raw search response body (the legacy API parses it itself).
    def search_json(title, modifier: HTMLRequests::SearchModifiers::NONE)
      post_search(title, modifier)
    rescue EndpointGone
      forget_endpoint!
      begin
        post_search(title, modifier)
      rescue EndpointGone
        raise RequestError, 'HLTB search endpoint returns 404 even after rediscovery'
      end
    end

    private

    def post_search(title, modifier)
      endpoint = current_endpoint
      auth = current_token(endpoint)
      headers = HTMLRequests.get_search_request_headers(auth)
      body = HTMLRequests.get_search_request_data(title, modifier, 1, endpoint.search_info, auth)
      response = @http.post("#{BASE_URL}#{endpoint.path}", headers, body)
      raise EndpointGone if response.code == 404

      response.body
    end

    def current_endpoint
      return @endpoint if @endpoint && @clock.call - @endpoint.found_at < @endpoint_ttl

      @token = nil
      @endpoint = discover
    end

    def forget_endpoint!
      @endpoint = nil
      @token = nil
    end

    def current_token(endpoint)
      return @token.auth if @token && @clock.call - @token.issued_at < @token_ttl

      response = @http.get(init_url(endpoint.path))
      raise EndpointGone if response.code == 404

      @token = Token.new(parse_auth(response.body), @clock.call)
      @sleeper.call(@token_warmup)
      @token.auth
    end

    def init_url(path)
      "#{BASE_URL}#{path}/init?t=#{Time.now.to_i}"
    end

    def parse_auth(body)
      json = JSON.parse(body.to_s)
      raise ParseError, 'HLTB /init response is not an object' unless json.is_a?(Hash)

      token = json['token'] || json.dig('data', 'token') || json['auth_token'] || json['authToken']
      key = json.find { |name, _| name.downcase.include?('key') }&.last
      value = json.find { |name, _| name.downcase.include?('val') }&.last
      HTMLRequests::AuthStruct.new(token, key, value)
    rescue JSON::ParserError => e
      raise ParseError, "HLTB /init response is not JSON: #{e.message}"
    end

    # The search call is the POST fetch in HLTB's JS bundle that sends
    # x-auth-token. Chunk names are opaque, so walk them in page order.
    def discover
      homepage = @http.get(BASE_URL)
      raise RequestError, 'HLTB homepage returned 404' if homepage.code == 404

      Nokogiri::HTML(homepage.body).css('script[src]').each do |script|
        info = search_info_from(script['src'])
        return Endpoint.new("/#{info.search_url}", info, @clock.call) if info
      end

      fallback_endpoint
    end

    def search_info_from(src)
      url = src.start_with?('http') ? src : "#{BASE_URL}#{src}"
      response = @http.get(url)
      return nil unless response.code == 200

      info = HTMLRequests::SearchInfo.new(response.body)
      info if info.authenticated? && !info.search_url.to_s.empty?
    rescue RequestError
      nil # a redirected or broken chunk (e.g. the consent script) is not fatal
    end

    def fallback_endpoint
      KNOWN_SEARCH_PATHS.each do |path|
        return Endpoint.new(path, nil, @clock.call) if @http.get(init_url(path)).code == 200
      end

      raise RequestError, 'Could not discover the HLTB search endpoint'
    end
  end
end
