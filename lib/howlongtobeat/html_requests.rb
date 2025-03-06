require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'

module HowLongToBeat
  class HTMLRequests
    BASE_URL = 'https://howlongtobeat.com'
    REFERER_HEADER = BASE_URL
    GAME_URL = "#{BASE_URL}/game"
    SEARCH_URL = "#{BASE_URL}/api/search"

    class SearchModifiers
      NONE = ""
      ISOLATE_DLC = "only_dlc"
      ISOLATE_MODS = "only_mods"
      ISOLATE_HACKS = "only_hacks"
      HIDE_DLC = "hide_dlc"
    end

    class SearchInfo
      attr_accessor :search_url, :api_key

      def initialize(script_content)
        @api_key = extract_api_from_script(script_content)
        @search_url = extract_search_url_script(script_content)
        @search_url = @search_url&.strip&.gsub(/^\/+|\/+$/, '')
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
        pattern = /fetch\(\s*["'](\/api\/[^"']*)['"]((?:\s*\.concat\(\s*["']([^"']*)['"]\s*\))+)\s*,/
        if (matches = script_content.match(pattern))
          endpoint = matches[1]
          concat_calls = matches[2]
          concat_strings = concat_calls.scan(/\.concat\(\s*["']([^"']*)['"]\s*\)/).flatten
          concatenated_str = concat_strings.join
          concatenated_str = concatenated_str.gsub(/["\(\)\[\]'\\]/, '')
          return endpoint if concatenated_str == @api_key
        end
        nil
      end
    end

    class << self
      def get_search_request_headers
        {
          'content-type' => 'application/json',
          'accept' => '*/*',
          'User-Agent' => random_user_agent,
          'referer' => REFERER_HEADER
        }
      end

      def get_search_request_data(game_name, search_modifiers = SearchModifiers::NONE, page = 1, search_info = nil)
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

        payload.to_json
      end

      def send_web_request(game_name, search_modifiers = SearchModifiers::NONE, page = 1)
        headers = get_search_request_headers
        search_info = send_website_request_getcode(false)
        search_info ||= send_website_request_getcode(true)

        return nil unless search_info&.api_key

        if search_info.search_url
          search_url = "#{BASE_URL}/#{search_info.search_url}"
        else
          search_url = SEARCH_URL
        end

        # Try with API key in URL
        search_url_with_key = "#{search_url}/#{search_info.api_key}"
        payload = get_search_request_data(game_name, search_modifiers, page)
        response = make_request(search_url_with_key, headers, payload)
        return response if response

        # Fallback to standard search with API key in payload
        payload = get_search_request_data(game_name, search_modifiers, page, search_info)
        make_request(search_url, headers, payload)
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

      def send_website_request_getcode(parse_all_scripts)
        headers = get_title_request_headers
        response = make_get_request(BASE_URL, headers)
        return nil unless response

        doc = Nokogiri::HTML(response)
        script_urls = doc.css('script[src]').map { |script| script['src'] }

        scripts = parse_all_scripts ? script_urls : script_urls.select { |url| url.include?('_app-') }

        scripts.each do |script_url|
          url = script_url.start_with?('http') ? script_url : "#{BASE_URL}#{script_url}"
          script_content = make_get_request(url, headers)
          next unless script_content

          search_info = SearchInfo.new(script_content)
          return search_info if search_info.api_key && !search_info.api_key.empty?
        end

        nil
      end

      def get_title_request_headers
        {
          'User-Agent' => random_user_agent,
          'referer' => REFERER_HEADER
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
      rescue StandardError => e
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
      rescue StandardError => e
        nil
      end

      def random_user_agent
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      end
    end
  end
end
