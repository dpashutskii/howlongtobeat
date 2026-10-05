require 'date'

module HowLongToBeat
  # Conversions shared by the game-page and search parsers.
  module Fields
    module_function

    # HLTB reports times in seconds; 0 means "no data".
    def hours(seconds)
      value = seconds.to_f
      value.positive? ? (value / 3600.0).round(2) : nil
    end

    def aliases(value)
      value.to_s.split(',').map(&:strip).reject(&:empty?)
    end

    def positive_int(value)
      number = value.to_i
      number.positive? ? number : nil
    end

    # Game pages send "2015-05-19"; search rows send 2015.
    def release_date(value)
      Date.iso8601(value.to_s) if value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    rescue Date::Error
      nil
    end

    def release_year(value)
      year = value.to_s[/\A\d{4}/].to_i
      year.positive? ? year : nil
    end

    def times(game)
      {
        main_story: hours(game['comp_main']),
        main_extra: hours(game['comp_plus']),
        completionist: hours(game['comp_100']),
        all_styles: hours(game['comp_all']),
        coop: hours(game['invested_co']),
        multiplayer: hours(game['invested_mp'])
      }
    end
  end
end
