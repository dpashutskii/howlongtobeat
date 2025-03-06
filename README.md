# HowLongToBeat Ruby API

![CI](https://github.com/dpashutskii/howlongtobeat/actions/workflows/ci.yml/badge.svg)

A simple Ruby API to read data from howlongtobeat.com.

It is inspired by [ScrappyCocco's HowLongToBeat Python API](https://github.com/ScrappyCocco/HowLongToBeat-PythonAPI).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'howlongtobeat'
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install howlongtobeat
```

## Usage

### Basic Search

```ruby
require 'howlongtobeat'

hltb = HowLongToBeat::HowLongToBeat.new
results = hltb.search("The Witcher 3")
```

The `search` method returns an array of possible games, or `nil` if no results were found or there was an error in the request.

Each result is an array of [`HowLongToBeat::HowLongToBeatEntry`](https://github.com/dpashutskii/howlongtobeat/blob/main/lib/howlongtobeat/how_long_to_beat_entry.rb) objects containing:

#### Base Game Details
- `game_id`: The game's ID on HowLongToBeat (Integer)
- `game_name`: The game's name (String)
- `game_alias`: Alternative names for the game (String)
- `game_type`: Type of content (e.g., "game", "dlc") (String)
- `game_image_url`: URL to the game's cover image (String)
- `game_web_link`: URL to the game's HowLongToBeat page (String)
- `review_score`: User review score (Integer, 0-100)
- `profile_dev`: Developer information (String)
- `profile_platforms`: Available platforms (Array of Strings)
- `release_world`: Release year (Integer)

#### Completion Times (all in hours)
- `main_story`: Main story completion time (Float)
- `main_extra`: Main story + side quests completion time (Float)
- `completionist`: 100% completion time (Float)
- `all_styles`: Average time across all playstyles (Float)
- `coop_time`: Co-op gameplay time (Float)
- `mp_time`: Multiplayer gameplay time (Float)

#### Complexity Flags
- `complexity_lvl_combine`: Combined gameplay complexity (Boolean)
- `complexity_lvl_sp`: Single-player complexity (Boolean)
- `complexity_lvl_co`: Co-op complexity (Boolean)
- `complexity_lvl_mp`: Multiplayer complexity (Boolean)

#### Other
- `similarity`: How closely the game name matches the search query (Float, 0.0 to 1.0)
- `json_content`: Raw JSON data from the API (Hash)

### Search by ID

You can also search for a game using its HowLongToBeat ID:

```ruby
result = hltb.search_from_id(10270)  # The Witcher 3: Wild Hunt
```

This returns a single `HowLongToBeatEntry` object or `nil` if not found.

### Search Modifiers

You can filter your search results using modifiers:

```ruby
hltb = HowLongToBeat::HowLongToBeat.new
results = hltb.search("The Witcher 3", HowLongToBeat::HTMLRequests::SearchModifiers::HIDE_DLC)
```

Available modifiers:
- `NONE`: Default search (includes DLCs)
- `ISOLATE_DLC`: Show only DLCs
- `ISOLATE_MODS`: Show only mods
- `ISOLATE_HACKS`: Show only hacks
- `HIDE_DLC`: Hide DLCs and show only games

### Similarity Filtering

By default, the search filters results with a similarity score greater than 0.4. You can adjust this threshold:

```ruby
# Return all results without filtering
hltb = HowLongToBeat::HowLongToBeat.new(0.0)
results = hltb.search("The Witcher 3")

# Use a higher threshold for stricter matching
hltb = HowLongToBeat::HowLongToBeat.new(0.7)
results = hltb.search("The Witcher 3")
```

## Who's Using It

This gem was originally created for and is being used by [SearchToPlay](https://searchtoplay.com), a platform that helps gamers discover and track their gaming journey.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake test` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the MIT License.
