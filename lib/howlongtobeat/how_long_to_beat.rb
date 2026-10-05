module HowLongToBeat
  # The original API, kept for existing callers. It now runs on Client, so
  # it shares the pacing, caching and error handling; any failure still
  # returns nil, as before.
  #
  # Note: search_from_id now builds entries from the game page only. It sets
  # id, name, alias, type, web link, release year, and the six time fields
  # (main_story, main_extra, completionist, all_styles, coop_time, mp_time)
  # plus similarity (1.0). Image URL, review score, developer, platforms,
  # JSON content, and complexity flags stay unset. auto_filter_times does
  # not apply to search_from_id results.
  class HowLongToBeat
    def initialize(input_minimum_similarity = 0.4, input_auto_filter_times = false, client: Client.new)
      @minimum_similarity = input_minimum_similarity
      @auto_filter_times = input_auto_filter_times
      @client = client
    end

    def search(game_name, search_modifiers = HTMLRequests::SearchModifiers::NONE,
               similarity_case_sensitive = true)
      return nil if game_name.nil? || game_name.empty?

      json = @client.search_json(game_name, modifier: search_modifiers)
      # Validate the shape first; SearchResultParser raises ParseError for any
      # malformed response, which rescue Error below will turn into nil.
      SearchResultParser.parse(json)
      parse_web_result(game_name, json, nil, similarity_case_sensitive)
    rescue Error
      nil
    end

    def search_from_id(game_id)
      return nil if game_id.nil? || game_id == 0
      # Validate the ID is numeric before calling the client; game_id is expected to be
      # an integer, but Integer() will coerce strings like "123" and raise ArgumentError on "abc"
      return nil unless game_id.is_a?(Integer) || (game_id.is_a?(String) && game_id.match?(/^\d+$/))

      detail = @client.game(game_id)
      detail && entry_from(detail)
    rescue Error, ArgumentError
      nil
    end

    private

    def entry_from(detail)
      HowLongToBeatEntry.new.tap do |entry|
        entry.game_id = detail.id
        entry.game_name = detail.name
        entry.game_alias = detail.aliases.join(', ')
        entry.game_type = detail.game_type
        entry.game_web_link = "#{JSONResultParser::GAME_URL_PREFIX}#{detail.id}"
        entry.release_world = detail.release_year
        entry.main_story = detail.main_story
        entry.main_extra = detail.main_extra
        entry.completionist = detail.completionist
        entry.all_styles = detail.all_styles
        entry.coop_time = detail.coop
        entry.mp_time = detail.multiplayer
        entry.similarity = 1.0
      end
    end

    def parse_web_result(game_name, html_result, game_id = nil, similarity_case_sensitive = true)
      parser = JSONResultParser.new(
        game_name,
        HTMLRequests::GAME_URL,
        @minimum_similarity,
        game_id,
        similarity_case_sensitive,
        @auto_filter_times
      )

      parser.parse_json_result(html_result)
      parser.results
    end
  end
end
