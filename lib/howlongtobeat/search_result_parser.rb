require 'json'

module HowLongToBeat
  # Turns the search API response into SearchResult rows. An empty `data`
  # array is a genuine "not on HLTB"; any other shape is a ParseError.
  module SearchResultParser
    module_function

    def parse(json)
      payload = JSON.parse(json.to_s.dup.force_encoding(Encoding::UTF_8))
      games = payload['data'] if payload.is_a?(Hash)
      raise ParseError, 'HLTB search response has no data array' unless games.is_a?(Array)

      games.map do |game|
        raise ParseError, 'HLTB search response game row is not a dict' unless game.is_a?(Hash)
        raise ParseError, 'HLTB search response game row has no game_id' unless game['game_id']

        SearchResult.new(
          id: game['game_id'].to_i,
          name: game['game_name'],
          aliases: Fields.aliases(game['game_alias']),
          release_year: Fields.release_year(game['release_world']),
          game_type: game['game_type'],
          **Fields.times(game)
        )
      end
    rescue JSON::ParserError => e
      raise ParseError, "HLTB search response is not JSON: #{e.message}"
    rescue NoMethodError, TypeError => e
      raise ParseError, "HLTB search response has unexpected structure: #{e.message}"
    end
  end
end
