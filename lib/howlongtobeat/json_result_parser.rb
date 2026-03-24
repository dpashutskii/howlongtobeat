require 'json'
require 'set'

module HowLongToBeat
  class JSONResultParser
    IMAGE_URL_PREFIX = "https://howlongtobeat.com/games/"
    GAME_URL_PREFIX = "https://howlongtobeat.com/game/"

    attr_reader :results

    def initialize(input_game_name, input_game_url, input_minimum_similarity, input_game_id = nil,
                 input_similarity_case_sensitive = true, input_auto_filter_times = false)
      @results = []
      @minimum_similarity = input_minimum_similarity
      @similarity_case_sensitive = input_similarity_case_sensitive
      @auto_filter_times = input_auto_filter_times
      @game_id = input_game_id
      @base_game_url = input_game_url
      @game_name = input_game_name
      @game_name_numbers = @game_name.split(" ").select { |word| word.match?(/^\d+$/) }

      if @game_id
        @minimum_similarity = 0
        @similarity_case_sensitive = false
      end
    end

    def parse_json_result(input_json_result)
      response_result = JSON.parse(input_json_result)
      games = extract_games(response_result)
      return if games.nil? || games.empty?

      games.each do |game|
        new_game_entry = parse_json_element(game)

        if @game_id && new_game_entry.game_id.to_s != @game_id.to_s
          next
        elsif @minimum_similarity == 0.0
          @results << new_game_entry
        elsif new_game_entry.similarity >= @minimum_similarity
          @results << new_game_entry
        end
      end
    end

    private

    def extract_games(response_result)
      return response_result if response_result.is_a?(Array)
      return [] unless response_result.is_a?(Hash)

      %w[data results result items games].each do |key|
        value = response_result[key]
        return value if value.is_a?(Array)
      end

      []
    end

    def field(input, *keys)
      keys.each do |key|
        return input[key] if input.key?(key)
      end
      nil
    end

    def normalize_platforms(value)
      return value if value.is_a?(Array)
      return nil if value.nil?
      value.to_s.split(", ")
    end

    def normalize_time(value)
      return nil if value.nil?
      time_value = value.to_f
      return nil if time_value <= 0

      # Older payloads expose seconds; some variants may already use hours.
      if time_value > 500
        round_time(time_value)
      else
        time_value.round(2)
      end
    end

    def parse_json_element(input_game_element)
      current_entry = HowLongToBeatEntry.new

      # Base fields
      current_entry.game_id = field(input_game_element, "game_id", "gameId", "id")
      current_entry.game_name = field(input_game_element, "game_name", "gameName", "name")
      current_entry.game_alias = field(input_game_element, "game_alias", "gameAlias", "alias")
      current_entry.game_type = field(input_game_element, "game_type", "gameType", "type")
      game_image = field(input_game_element, "game_image", "gameImage", "image")
      current_entry.game_image_url = "#{IMAGE_URL_PREFIX}#{game_image}" if game_image
      current_entry.game_web_link = "#{GAME_URL_PREFIX}#{current_entry.game_id}"
      current_entry.review_score = field(input_game_element, "review_score", "reviewScore", "score")
      current_entry.profile_dev = field(input_game_element, "profile_dev", "profileDev", "developer")
      current_entry.profile_platforms = normalize_platforms(field(input_game_element, "profile_platform", "profilePlatform", "platforms"))
      current_entry.release_world = field(input_game_element, "release_world", "releaseWorld", "releaseYear")
      current_entry.json_content = input_game_element

      # Completion times
      current_entry.main_story = normalize_time(field(input_game_element, "comp_main", "compMain", "main_story", "mainStory"))
      current_entry.main_extra = normalize_time(field(input_game_element, "comp_plus", "compPlus", "main_extra", "mainExtra"))
      current_entry.completionist = normalize_time(field(input_game_element, "comp_100", "comp100", "completionist"))
      current_entry.all_styles = normalize_time(field(input_game_element, "comp_all", "compAll", "all_styles", "allStyles"))
      current_entry.coop_time = normalize_time(field(input_game_element, "invested_co", "investedCo", "coop_time", "coopTime"))
      current_entry.mp_time = normalize_time(field(input_game_element, "invested_mp", "investedMp", "mp_time", "mpTime"))

      # Complexity flags
      current_entry.complexity_lvl_combine = field(input_game_element, "comp_lvl_combine", "compLvlCombine", "complexity_lvl_combine", "complexityLvlCombine").to_i == 1
      current_entry.complexity_lvl_sp = field(input_game_element, "comp_lvl_sp", "compLvlSp", "complexity_lvl_sp", "complexityLvlSp").to_i == 1
      current_entry.complexity_lvl_co = field(input_game_element, "comp_lvl_co", "compLvlCo", "complexity_lvl_co", "complexityLvlCo").to_i == 1
      current_entry.complexity_lvl_mp = field(input_game_element, "comp_lvl_mp", "compLvlMp", "complexity_lvl_mp", "complexityLvlMp").to_i == 1

      # Auto-filter times based on complexity
      if @auto_filter_times
        if !current_entry.complexity_lvl_sp
          current_entry.main_story = nil
          current_entry.main_extra = nil
          current_entry.completionist = nil
          current_entry.all_styles = nil
        end
        current_entry.coop_time = nil unless current_entry.complexity_lvl_co
        current_entry.mp_time = nil unless current_entry.complexity_lvl_mp
      end

      # Calculate similarity
      game_name_similarity = similar(@game_name, current_entry.game_name)
      game_alias_similarity = similar(@game_name, current_entry.game_alias)
      current_entry.similarity = [game_name_similarity, game_alias_similarity].max

      current_entry
    end

    def similar(a, b)
      return 0 if a.nil? || b.nil?

      a = a.downcase unless @similarity_case_sensitive
      b = b.downcase unless @similarity_case_sensitive

      # Simple Levenshtein distance for similarity
      distance = levenshtein_distance(a, b)
      max_length = [a.length, b.length].max
      similarity = 1 - (distance.to_f / max_length)

      # Additional check for numbers
      if @game_name_numbers.any?
        cleaned = b.gsub(/[^\w\s]/, '')
        number_found = cleaned.split.any? do |word|
          word.match?(/^\d+$/) && @game_name_numbers.include?(word)
        end
        similarity -= 0.1 unless number_found
      end

      similarity
    end

    def levenshtein_distance(str1, str2)
      m = str1.length
      n = str2.length
      return m if n == 0
      return n if m == 0

      matrix = Array.new(m + 1) { Array.new(n + 1) }

      (0..m).each { |i| matrix[i][0] = i }
      (0..n).each { |j| matrix[0][j] = j }

      (1..n).each do |j|
        (1..m).each do |i|
          if str1[i-1] == str2[j-1]
            matrix[i][j] = matrix[i-1][j-1]
          else
            matrix[i][j] = [
              matrix[i-1][j] + 1,
              matrix[i][j-1] + 1,
              matrix[i-1][j-1] + 1
            ].min
          end
        end
      end

      matrix[m][n]
    end

    def round_time(seconds)
      return nil if seconds.nil?
      (seconds / 3600.0).round(2)
    end
  end
end
