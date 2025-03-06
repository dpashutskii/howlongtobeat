require_relative 'howlongtobeat/version'
require_relative 'howlongtobeat/how_long_to_beat'
require_relative 'howlongtobeat/how_long_to_beat_entry'
require_relative 'howlongtobeat/html_requests'
require_relative 'howlongtobeat/json_result_parser'

module HowLongToBeat
  class Error < StandardError; end
end
