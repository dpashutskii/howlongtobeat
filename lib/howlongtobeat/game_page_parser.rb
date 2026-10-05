require 'json'

module HowLongToBeat
  # Reads the record Next.js embeds in every /game/<id> page, so refreshing
  # a known game takes one GET and no search or auth token.
  module GamePageParser
    NEXT_DATA = %r{<script id="__NEXT_DATA__" type="application/json">(.*?)</script>}m

    module_function

    def parse(html)
      json = html.to_s.dup.force_encoding(Encoding::UTF_8)[NEXT_DATA, 1]
      raise ParseError, 'HLTB game page has no __NEXT_DATA__ script' unless json

      game = JSON.parse(json).dig('props', 'pageProps', 'game', 'data', 'game')
      game = game.first if game.is_a?(Array)
      raise ParseError, 'HLTB game page has no game record' unless game.is_a?(Hash) && game['game_id']

      GameDetail.new(
        id: game['game_id'].to_i,
        name: game['game_name'],
        aliases: Fields.aliases(game['game_alias']),
        release_date: Fields.release_date(game['release_world']),
        release_year: Fields.release_year(game['release_world']),
        steam_app_id: Fields.positive_int(game['profile_steam']),
        game_type: game['game_type'],
        **Fields.times(game)
      )
    rescue JSON::ParserError => e
      raise ParseError, "HLTB game page JSON is invalid: #{e.message}"
    end
  end
end
