module HowLongToBeat
  class HowLongToBeatEntry
    # Base Game Details
    attr_accessor :game_id, :game_name, :game_alias, :game_type, :game_image_url,
                 :game_web_link, :review_score, :profile_dev, :profile_platforms,
                 :release_world, :similarity, :json_content

    # Completion times
    attr_accessor :main_story, :main_extra, :completionist, :all_styles,
                 :coop_time, :mp_time

    # Complexity flags
    attr_accessor :complexity_lvl_combine, :complexity_lvl_sp,
                 :complexity_lvl_co, :complexity_lvl_mp

    def initialize
      # Initialize with default values
      @game_id = -1
      @game_name = nil
      @game_alias = nil
      @game_type = nil
      @game_image_url = nil
      @game_web_link = nil
      @review_score = nil
      @profile_dev = nil
      @profile_platforms = nil
      @release_world = nil
      @similarity = -1
      @json_content = nil

      # Completion times
      @main_story = nil
      @main_extra = nil
      @completionist = nil
      @all_styles = nil
      @coop_time = nil
      @mp_time = nil

      # Complexity flags
      @complexity_lvl_combine = false
      @complexity_lvl_sp = false
      @complexity_lvl_co = false
      @complexity_lvl_mp = false
    end

    def to_s
      times = []
      times << "Main Story: #{main_story}h" if main_story
      times << "Main + Extra: #{main_extra}h" if main_extra
      times << "Completionist: #{completionist}h" if completionist
      times << "All Styles: #{all_styles}h" if all_styles
      times << "Co-op: #{coop_time}h" if coop_time
      times << "Multiplayer: #{mp_time}h" if mp_time

      "#{game_name} (ID: #{game_id}) - #{times.join(', ')}"
    end
  end
end
