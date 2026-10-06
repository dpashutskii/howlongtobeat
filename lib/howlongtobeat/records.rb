module HowLongToBeat
  # A game as its /game/<id> page describes it. Times are hours, nil when
  # HLTB has no data.
  GameDetail = Struct.new(
    :id, :name, :aliases, :release_date, :release_year, :steam_app_id, :game_type,
    :main_story, :main_extra, :completionist, :all_styles, :coop, :multiplayer,
    keyword_init: true
  )

  # One row of a title search. Search rows carry a release year, not a date,
  # and no Steam id; fetch the game page for those.
  SearchResult = Struct.new(
    :id, :name, :aliases, :release_year, :game_type,
    :main_story, :main_extra, :completionist, :all_styles, :coop, :multiplayer,
    keyword_init: true
  )
end
