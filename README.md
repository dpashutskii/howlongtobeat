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

Each result is a `HowLongToBeat::Entry` object containing:
- `id`: The game's ID on HowLongToBeat
- `name`: The game's name
- `description`: Game description
- `main_story`: Main story completion time
- `main_plus_sides`: Main story + side quests completion time
- `completionist`: 100% completion time
- `all_styles`: Average time across all playstyles
- `similarity`: How closely the game name matches the search query (0.0 to 1.0)

### Search by ID

You can also search for a game using its HowLongToBeat ID:

```ruby
result = hltb.search_from_id(10270)  # The Witcher 3: Wild Hunt
```

This returns a single `Entry` object or `nil` if not found.

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

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake test` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the MIT License.
