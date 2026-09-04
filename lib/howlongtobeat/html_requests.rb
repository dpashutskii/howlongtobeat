require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'

module HowLongToBeat
  class HTMLRequests
    BASE_URL = 'https://howlongtobeat.com'
    REFERER_HEADER = BASE_URL
    GAME_URL = "#{BASE_URL}/game"
    # HLTB renames this endpoint periodically
    # (most recent: /api/find -> /api/finder -> /api/bleed -> /api/search/site).
    # The runtime discovery in `send_website_request_getcode` is the source of truth;
    # this constant is the fallback when discovery fails.
    SEARCH_URL = "#{BASE_URL}/api/search/site"

    class SearchModifiers
      NONE = ""
      ISOLATE_DLC = "only_dlc"
      ISOLATE_MODS = "only_mods"
      ISOLATE_HACKS = "only_hacks"
      HIDE_DLC = "hide_dlc"
    end

    class SearchInfo
      attr_accessor :search_url, :api_key

      # A POST fetch to /api/... whose request options mention x-auth-token.
      # This is the signature of the search call and distinguishes it from
      # other POST fetches in the bundle (e.g. /api/error).
      AUTHENTICATED_FETCH_MARKER = /x-auth-token/i

      def initialize(script_content)
        @api_key = extract_api_from_script(script_content)
        @authenticated = false
        @search_url = extract_search_url_script(script_content)
        @search_url = @search_url&.strip&.gsub(/^\/+|\/+$/, '')
      end

      # True when the discovered search_url came from a fetch that sends
      # x-auth-token. Callers use this to prefer the real search endpoint over
      # any other POST fetch found in an earlier script.
      def authenticated?
        @authenticated
      end

      private

      def extract_api_from_script(script_content)
        if (matches = script_content.scan(/users\s*:\s*{\s*id\s*:\s*"([^"]+)"/))
          key = matches.flatten.first
          return key if key && !key.empty?
        end

        if (matches = script_content.scan(/\/api\/\w+\/"(?:\.concat\("[^"]*"\))*/))
          matches_str = matches.to_s
          concat_parts = matches_str.split('.concat')[1..]
          concat_parts = concat_parts.map { |part| part.gsub(/["\(\)\[\]'\\]/, '') }
          key = concat_parts.join
          return key if key && !key.empty?
        end

        nil
      end

      def extract_search_url_script(script_content)
        # Prefer the search endpoint used in POST fetch calls, which is more stable
        # than hardcoding "/api/search" and works with variants like "/api/finder",
        # "/api/bleed" and nested paths like "/api/search/site" (current as of
        # 2026-09). The full path is kept verbatim: truncating to the first
        # segment turned "/api/search/site" into "/api/search", which 404s.
        post_fetch_pattern = /fetch\s*\(\s*["']\/api\/([a-zA-Z0-9_\/-]+)[^"']*["']\s*,\s*({[^}]*method:\s*["']POST["'][^}]*})/mi
        matches = script_content.to_enum(:scan, post_fetch_pattern).map { Regexp.last_match }
        unless matches.empty?
          # A single chunk can contain several POST fetches; the search one is
          # the one that sends x-auth-token. Fall back to the first POST fetch
          # so a header rename doesn't leave us with nothing.
          match = matches.find { |m| m[2].match?(AUTHENTICATED_FETCH_MARKER) }
          @authenticated = !match.nil?
          match ||= matches.first
          path_suffix = match[1].sub(%r{/+\z}, '')
          return "/api/#{path_suffix}"
        end

        # Legacy fallback for previous script shape using .concat(...)
        legacy_pattern = /fetch\(\s*["'](\/api\/[^"']*)['"]((?:\s*\.concat\(\s*["']([^"']*)['"]\s*\))+)\s*,/
        if (matches = script_content.match(legacy_pattern))
          endpoint = matches[1]
          concat_calls = matches[2]
          concat_strings = concat_calls.scan(/\.concat\(\s*["']([^"']*)['"]\s*\)/).flatten
          concatenated_str = concat_strings.join.gsub(/["\(\)\[\]'\\]/, '')
          return endpoint if concatenated_str == @api_key
        end

        nil
      end
    end

    AuthStruct = Struct.new(:auth_token, :auth_key, :auth_value)

    class << self
      def get_search_request_headers(auth_struct = nil)
        headers = {
          'content-type' => 'application/json',
          'accept' => '*/*',
          'User-Agent' => random_user_agent,
          'Referer' => REFERER_HEADER,
          'Origin' => BASE_URL
        }

        if auth_struct
          headers['x-auth-token'] = auth_struct.auth_token.to_s if auth_struct.auth_token
          headers['x-hp-key'] = auth_struct.auth_key.to_s if auth_struct.auth_key
          headers['x-hp-val'] = auth_struct.auth_value.to_s if auth_struct.auth_value
        end

        headers
      end

      def get_search_request_data(game_name, search_modifiers = SearchModifiers::NONE, page = 1, search_info = nil, auth_struct = nil)
        payload = {
          searchType: 'games',
          searchTerms: game_name.split,
          searchPage: page,
          size: 20,
          searchOptions: {
            games: {
              userId: 0,
              platform: '',
              sortCategory: 'popular',
              rangeCategory: 'main',
              rangeTime: { min: 0, max: 0 },
              gameplay: {
                perspective: '',
                flow: '',
                genre: '',
                difficulty: ''
              },
              rangeYear: {
                max: '',
                min: ''
              },
              modifier: search_modifiers
            },
            users: {
              sortCategory: 'postcount'
            },
            lists: {
              sortCategory: 'follows'
            },
            filter: '',
            sort: 0,
            randomizer: 0
          },
          useCache: true
        }

        if search_info&.api_key
          payload[:searchOptions][:users][:id] = search_info.api_key
        end

        if auth_struct&.auth_key && auth_struct&.auth_value
          payload[auth_struct.auth_key] = auth_struct.auth_value
        end

        payload.to_json
      end

      def send_web_request(game_name, search_modifiers = SearchModifiers::NONE, page = 1)
        search_info = send_website_request_getcode

        endpoint_candidates = build_endpoint_candidates(search_info&.search_url)

        endpoint_candidates.each do |endpoint|
          auth_struct = fetch_search_token(endpoint)
          next unless auth_struct

          headers = get_search_request_headers(auth_struct)
          payload = get_search_request_data(game_name, search_modifiers, page, search_info, auth_struct)
          search_url = "#{BASE_URL}#{endpoint}"
          response = make_request(search_url, headers, payload)
          return response if response
        end

        nil
      end

      def get_game_title(game_id)
        url = "#{GAME_URL}/#{game_id}"
        headers = get_title_request_headers

        contents = make_get_request(url, headers)
        return nil unless contents

        doc = Nokogiri::HTML(contents)
        title_tag = doc.title
        return nil unless title_tag

        title_text = title_tag
        title_text[12...-17]&.strip
      end

      private

      def fetch_search_token(parsed_search_url = nil)
        base_endpoint = parsed_search_url.to_s.strip
        base_endpoint = '/api/search/site' if base_endpoint.empty?
        base_endpoint = "/#{base_endpoint}" unless base_endpoint.start_with?('/')
        base_endpoint = base_endpoint.sub(%r{/+\z}, '')
        base_endpoint = base_endpoint.sub(%r{/init\z}, '')

        url = "#{BASE_URL}#{base_endpoint}/init?t=#{Time.now.to_i}"
        headers = get_title_request_headers
        response = make_get_request(url, headers)
        return nil unless response

        json = JSON.parse(response) rescue nil
        return nil unless json.is_a?(Hash)

        token = json['token'] || json.dig('data', 'token') || json['auth_token'] || json['authToken']

        auth_key = nil
        auth_value = nil
        json.each do |field_name, field_value|
          lower = field_name.downcase
          if lower.match?(/key/)
            auth_key = field_value
          elsif lower.match?(/val/)
            auth_value = field_value
          end
        end

        AuthStruct.new(token, auth_key, auth_value)
      rescue StandardError
        nil
      end

      def build_endpoint_candidates(parsed_endpoint = nil)
        preferred = parsed_endpoint.to_s.strip
        candidates = []
        candidates << preferred unless preferred.empty?
        # Known historical endpoints, newest first. HLTB rotates this name periodically.
        candidates.concat(['/api/search/site', '/api/bleed', '/api/finder', '/api/search', '/api/s'])

        normalized = candidates.map do |endpoint|
          next nil if endpoint.nil? || endpoint.strip.empty?
          value = endpoint.strip
          value = "/#{value}" unless value.start_with?('/')
          value.sub(%r{/+\z}, '')
        end

        normalized.compact.uniq
      end

      # Walks every <script src> tag on the homepage looking for one that
      # contains a `fetch("/api/<name>", { method: "POST" })` call. HLTB used to
      # bundle the relevant code under `_app-*.js`, but the modern (Turbopack)
      # build emits opaque chunk names like `0-~-0up.q3_p0.js`, so a name-based
      # filter is no longer reliable — we iterate every script.
      #
      # The bundle also contains unrelated POST fetches (e.g. `/api/error`), and
      # chunk order is not stable, so we stop on the first chunk whose POST fetch
      # sends `x-auth-token` (the search call's signature) and only fall back to
      # the first plain POST fetch if no chunk is authenticated.
      def send_website_request_getcode
        headers = get_title_request_headers
        response = make_get_request(BASE_URL, headers)
        return nil unless response

        doc = Nokogiri::HTML(response)
        script_urls = doc.css('script[src]').map { |script| script['src'] }

        fallback = nil
        script_urls.each do |script_url|
          url = script_url.start_with?('http') ? script_url : "#{BASE_URL}#{script_url}"
          script_content = make_get_request(url, headers)
          next unless script_content

          search_info = SearchInfo.new(script_content)
          # Only consider a search_url match — an api_key without a search_url
          # leaves us with no idea where to POST.
          next unless search_info.search_url && !search_info.search_url.empty?

          return search_info if search_info.authenticated?
          fallback ||= search_info
        end

        fallback
      end

      def get_title_request_headers
        {
          'User-Agent' => random_user_agent,
          'referer' => REFERER_HEADER,
          'origin' => BASE_URL,
          'accept' => '*/*'
        }
      end

      def make_request(url, headers, payload)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.path, headers)
        request.body = payload

        response = http.request(request)
        response.body if response.is_a?(Net::HTTPSuccess)
      rescue OpenSSL::SSL::SSLError
        # SSL certificate verification failed - disable verification as fallback
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        response = http.request(request)
        response.is_a?(Net::HTTPSuccess) ? response.body : nil
      rescue StandardError
        nil
      end

      def make_get_request(url, headers)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri.request_uri, headers)
        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          response.body
        else
          nil
        end
      rescue OpenSSL::SSL::SSLError
        # SSL certificate verification failed - disable verification as fallback
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        response = http.request(request)
        response.is_a?(Net::HTTPSuccess) ? response.body : nil
      rescue StandardError
        nil
      end

      def random_user_agent
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      end
    end
  end
end
