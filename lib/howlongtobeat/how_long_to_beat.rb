module HowLongToBeat
  class HowLongToBeat
    def initialize(input_minimum_similarity = 0.4, input_auto_filter_times = false)
      @minimum_similarity = input_minimum_similarity
      @auto_filter_times = input_auto_filter_times
    end

    def search(game_name, search_modifiers = HTMLRequests::SearchModifiers::NONE,
              similarity_case_sensitive = true)
      return nil if game_name.nil? || game_name.empty?

      html_result = HTMLRequests.send_web_request(game_name, search_modifiers)
      return nil unless html_result

      parse_web_result(game_name, html_result, nil, similarity_case_sensitive)
    end

    def search_from_id(game_id)
      return nil if game_id.nil? || game_id == 0

      game_title = HTMLRequests.get_game_title(game_id)
      return nil unless game_title

      html_result = HTMLRequests.send_web_request(game_title)
      return nil unless html_result

      result_list = parse_web_result(game_title, html_result, game_id)
      return nil unless result_list && result_list.size == 1

      result_list.first
    end

    private

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
