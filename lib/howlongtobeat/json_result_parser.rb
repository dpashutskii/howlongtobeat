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
      response_result["data"].each do |game|
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

    def parse_json_element(input_game_element)
      current_entry = HowLongToBeatEntry.new

      # Base fields
      current_entry.game_id = input_game_element["game_id"]
      current_entry.game_name = input_game_element["game_name"]
      current_entry.game_alias = input_game_element["game_alias"]
      current_entry.game_type = input_game_element["game_type"]
      current_entry.game_image_url = "#{IMAGE_URL_PREFIX}#{input_game_element['game_image']}" if input_game_element["game_image"]
      current_entry.game_web_link = "#{GAME_URL_PREFIX}#{current_entry.game_id}"
      current_entry.review_score = input_game_element["review_score"]
      current_entry.profile_dev = input_game_element["profile_dev"]
      current_entry.profile_platforms = input_game_element["profile_platform"]&.split(", ")
      current_entry.release_world = input_game_element["release_world"]
      current_entry.json_content = input_game_element

      # Completion times
      current_entry.main_story = round_time(input_game_element["comp_main"])
      current_entry.main_extra = round_time(input_game_element["comp_plus"])
      current_entry.completionist = round_time(input_game_element["comp_100"])
      current_entry.all_styles = round_time(input_game_element["comp_all"])
      current_entry.coop_time = round_time(input_game_element["invested_co"])
      current_entry.mp_time = round_time(input_game_element["invested_mp"])

      # Complexity flags
      current_entry.complexity_lvl_combine = input_game_element["comp_lvl_combine"].to_i == 1
      current_entry.complexity_lvl_sp = input_game_element["comp_lvl_sp"].to_i == 1
      current_entry.complexity_lvl_co = input_game_element["comp_lvl_co"].to_i == 1
      current_entry.complexity_lvl_mp = input_game_element["comp_lvl_mp"].to_i == 1

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
