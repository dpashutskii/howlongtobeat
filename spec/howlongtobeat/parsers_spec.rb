require 'spec_helper'

RSpec.describe HowLongToBeat::GamePageParser do
  let(:html) { File.binread(File.expand_path('../fixtures/game_page.html', __dir__)) }

  it 'reads the game record embedded in the page' do
    detail = described_class.parse(html)

    expect(detail).to have_attributes(
      id: 10270,
      name: 'The Witcher 3: Wild Hunt',
      aliases: ['The Witcher III', 'Wiedźmin 3: Dziki Gon'],
      release_date: Date.new(2015, 5, 19),
      release_year: 2015,
      steam_app_id: 292030,
      game_type: 'game',
      main_story: 51.68,
      main_extra: 103.76,
      completionist: 175.27,
      all_styles: 104.41,
      coop: nil,
      multiplayer: nil
    )
  end

  it 'treats a zero Steam id as none' do
    detail = described_class.parse(html.sub('"profile_steam":292030', '"profile_steam":0'))

    expect(detail.steam_app_id).to be_nil
  end

  it 'raises ParseError when the page has no __NEXT_DATA__' do
    expect { described_class.parse('<html><body>maintenance</body></html>') }
      .to raise_error(HowLongToBeat::ParseError, /__NEXT_DATA__/)
  end

  it 'raises ParseError when the embedded JSON is invalid' do
    broken = '<script id="__NEXT_DATA__" type="application/json">{not json</script>'

    expect { described_class.parse(broken) }.to raise_error(HowLongToBeat::ParseError, /JSON/)
  end

  it 'raises ParseError when the JSON has no game record' do
    empty = '<script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{}}}</script>'

    expect { described_class.parse(empty) }.to raise_error(HowLongToBeat::ParseError, /game record/)
  end

  it 'raises ParseError when __NEXT_DATA__ is null' do
    null_data = '<script id="__NEXT_DATA__" type="application/json">null</script>'

    expect { described_class.parse(null_data) }.to raise_error(HowLongToBeat::ParseError)
  end

  it 'raises ParseError when __NEXT_DATA__ is wrong-shaped (not a dict with props)' do
    wrong_shape = '<script id="__NEXT_DATA__" type="application/json">{"props":"x"}</script>'

    expect { described_class.parse(wrong_shape) }.to raise_error(HowLongToBeat::ParseError)
  end

  it 'raises ParseError on invalid UTF-8 in __NEXT_DATA__' do
    invalid_utf8 = "<script id=\"__NEXT_DATA__\" type=\"application/json\">\xff</script>".b

    expect { described_class.parse(invalid_utf8) }.to raise_error(HowLongToBeat::ParseError)
  end

  it 'parses a script tag with extra attributes before id' do
    html_with_attrs = '<script type="application/json" id="__NEXT_DATA__" nonce="abc">' +
                      '{"props":{"pageProps":{"game":{"data":{"game":[{"game_id":123,"game_name":"Test","game_alias":"","game_type":"game","release_world":"2020-01-01","profile_steam":0,"comp_main":3600,"comp_plus":0,"comp_100":0,"comp_all":0,"invested_co":0,"invested_mp":0}]}}}}}' +
                      '</script>'

    detail = described_class.parse(html_with_attrs)
    expect(detail.id).to eq(123)
    expect(detail.name).to eq('Test')
  end
end

RSpec.describe HowLongToBeat::SearchResultParser do
  let(:json) do
    {
      data: [
        { game_id: 80569, game_name: 'Haven', game_alias: '', game_type: 'game', release_world: 2020,
          comp_main: 38820, comp_plus: 0, comp_100: 54000, comp_all: 40000, invested_co: 0, invested_mp: 0 },
        { game_id: 127854, game_name: 'Havendock', game_alias: nil, game_type: 'game', release_world: 2023,
          comp_main: 79330 }
      ]
    }.to_json
  end

  it 'returns one SearchResult per game' do
    results = described_class.parse(json)

    expect(results.map(&:id)).to eq([80569, 127854])
    expect(results.first).to have_attributes(
      name: 'Haven', aliases: [], release_year: 2020, game_type: 'game',
      main_story: 10.78, main_extra: nil, completionist: 15.0, all_styles: 11.11
    )
  end

  it 'returns an empty array when HLTB found nothing' do
    expect(described_class.parse({ data: [] }.to_json)).to eq([])
  end

  it 'raises ParseError when the response has no data array' do
    expect { described_class.parse({ error: 'nope' }.to_json) }.to raise_error(HowLongToBeat::ParseError, /data/)
  end

  it 'raises ParseError when the response is not JSON' do
    expect { described_class.parse('<html>') }.to raise_error(HowLongToBeat::ParseError, /JSON/)
  end

  it 'raises ParseError when a game row is null' do
    expect { described_class.parse({ data: [nil] }.to_json) }.to raise_error(HowLongToBeat::ParseError)
  end

  it 'raises ParseError when a game row has no game_id' do
    expect { described_class.parse({ data: [{ name: 'x' }] }.to_json) }.to raise_error(HowLongToBeat::ParseError)
  end
end
