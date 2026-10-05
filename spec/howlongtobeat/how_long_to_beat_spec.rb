require 'spec_helper'

RSpec.describe HowLongToBeat::HowLongToBeat, :live do
  let(:hltb) { described_class.new }
  let(:hltb_no_filter) { described_class.new(0.0) }
  let(:hltb_strict) { described_class.new(0.7) }

  describe '#search' do
    context 'with valid game name' do
      it 'returns an array of results' do
        results = hltb.search('The Witcher 3')
        expect(results).to be_an(Array)
        expect(results).not_to be_empty
      end

      it 'returns Entry objects with correct attributes' do
        results = hltb.search('The Witcher 3')
        entry = results.first

        expect(entry).to be_a(HowLongToBeat::HowLongToBeatEntry)
        expect(entry.game_id).not_to be_nil
        expect(entry.game_name).not_to be_nil
        expect(entry.main_story).to be_a(Float).or be_nil
        expect(entry.main_extra).to be_a(Float).or be_nil
        expect(entry.completionist).to be_a(Float).or be_nil
        expect(entry.all_styles).to be_a(Float).or be_nil
        expect(entry.similarity).to be_between(0.0, 1.0)
      end
    end

    context 'with invalid input' do
      it 'returns nil for nil input' do
        expect(hltb.search(nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(hltb.search('')).to be_nil
      end

      it 'returns empty array for non-existent game' do
        expect(hltb.search('ThisGameDefinitelyDoesNotExist12345')).to eq([])
      end
    end

    context 'with similarity thresholds' do
      it 'returns more results with no filtering' do
        strict_results = hltb_strict.search('Witcher')
        no_filter_results = hltb_no_filter.search('Witcher')
        expect(no_filter_results.length).to be >= strict_results.length
      end

      it 'returns results with higher similarity scores with strict filtering' do
        results = hltb_strict.search('Witcher')
        results.each do |result|
          expect(result.similarity).to be >= 0.7
        end
      end
    end

    context 'with search modifiers' do
      it 'can filter DLC content' do
        results = hltb.search('The Witcher 3', HowLongToBeat::HTMLRequests::SearchModifiers::HIDE_DLC)
        results.each do |result|
          expect(result.game_type).not_to include('DLC')
        end
      end

      it 'can show only DLC content' do
        results = hltb.search('The Witcher 3', HowLongToBeat::HTMLRequests::SearchModifiers::ISOLATE_DLC)
        results.each do |result|
          expect(result.game_type).to include('DLC')
        end unless results.empty?
      end
    end
  end

  describe '#search_from_id' do
    context 'with valid ID' do
      it 'returns a single Entry object' do
        result = hltb.search_from_id(10270) # The Witcher 3
        expect(result).to be_a(HowLongToBeat::HowLongToBeatEntry)
        expect(result.game_id).to eq(10270)
        expect(result.game_name).to include('Witcher')
      end
    end

    context 'with invalid ID' do
      it 'returns nil for nil input' do
        expect(hltb.search_from_id(nil)).to be_nil
      end

      it 'returns nil for zero' do
        expect(hltb.search_from_id(0)).to be_nil
      end

      it 'returns nil for non-existent ID' do
        expect(hltb.search_from_id(999999999)).to be_nil
      end
    end
  end
end

RSpec.describe HowLongToBeat::HowLongToBeat, 'on top of Client' do
  let(:client) { instance_double(HowLongToBeat::Client) }
  let(:hltb) { described_class.new(0.4, client: client) }
  let(:detail) do
    HowLongToBeat::GameDetail.new(
      id: 10270, name: 'The Witcher 3: Wild Hunt', aliases: ['The Witcher III'], release_date: Date.new(2015, 5, 19),
      release_year: 2015, steam_app_id: 292030, game_type: 'game', main_story: 51.68, main_extra: 103.76,
      completionist: 175.27, all_styles: 104.41, coop: nil, multiplayer: nil
    )
  end

  it 'filters search results by similarity like before' do
    json = { data: [{ game_id: 1, game_name: 'Haven' }, { game_id: 2, game_name: 'Completely Different' }] }.to_json
    allow(client).to receive(:search_json).with('Haven', modifier: '').and_return(json)

    expect(hltb.search('Haven').map(&:game_id)).to eq([1])
  end

  it 'passes search modifiers through' do
    allow(client).to receive(:search_json).with('Haven', modifier: 'hide_dlc').and_return({ data: [] }.to_json)

    expect(hltb.search('Haven', HowLongToBeat::HTMLRequests::SearchModifiers::HIDE_DLC)).to eq([])
  end

  it 'returns nil from search when HLTB rate-limits' do
    allow(client).to receive(:search_json).and_raise(HowLongToBeat::RateLimitedError)

    expect(hltb.search('Haven')).to be_nil
  end

  it 'builds search_from_id from the game page in one request' do
    allow(client).to receive(:game).with(10270).and_return(detail)

    entry = hltb.search_from_id(10270)

    expect(entry).to have_attributes(
      game_id: 10270, game_name: 'The Witcher 3: Wild Hunt', game_alias: 'The Witcher III',
      release_world: 2015, main_story: 51.68, completionist: 175.27, similarity: 1.0,
      game_web_link: 'https://howlongtobeat.com/game/10270'
    )
  end

  it 'returns nil from search_from_id for a missing game' do
    allow(client).to receive(:game).with(999).and_return(nil)

    expect(hltb.search_from_id(999)).to be_nil
  end

  it 'returns nil from search_from_id on a request error' do
    allow(client).to receive(:game).and_raise(HowLongToBeat::RequestError)

    expect(hltb.search_from_id(10270)).to be_nil
  end

  it 'returns nil from search when search_json returns malformed HTML' do
    allow(client).to receive(:search_json).with('Haven', modifier: '').and_return('<html>nope</html>')

    expect(hltb.search('Haven')).to be_nil
  end

  it 'returns nil from search when search_json returns wrong shape' do
    allow(client).to receive(:search_json).with('Haven', modifier: '').and_return({ data: [1] }.to_json)

    expect(hltb.search('Haven')).to be_nil
  end

  it 'returns nil from search_from_id for non-numeric id' do
    # Spy on the client to verify no call is made for invalid IDs
    spy_client = spy(HowLongToBeat::Client)
    hltb_with_spy = described_class.new(0.4, client: spy_client)

    expect(hltb_with_spy.search_from_id('abc')).to be_nil
    expect(spy_client).not_to have_received(:game)
  end
end
