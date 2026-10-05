require 'spec_helper'

RSpec.describe HowLongToBeat::Client do
  let(:base) { 'https://howlongtobeat.com' }
  let(:clock) { [0.0] }
  let(:sleeps) { [] }
  let(:sleeper) { ->(seconds) { sleeps << seconds; clock[0] += seconds } }
  let(:http) { HowLongToBeat::Http.new(min_interval: 0, clock: -> { clock.first }, sleeper: sleeper) }
  let(:client) { described_class.new(http: http, clock: -> { clock.first }, sleeper: sleeper) }
  let(:game_page) { File.binread(File.expand_path('../fixtures/game_page.html', __dir__)) }

  describe '#game' do
    it 'fetches the game page once and returns its record' do
      stub_request(:get, "#{base}/game/10270").to_return(status: 200, body: game_page)

      detail = client.game(10270)

      expect(detail).to have_attributes(id: 10270, steam_app_id: 292030, main_story: 51.68)
      expect(a_request(:get, "#{base}/game/10270")).to have_been_made.once
    end

    it 'accepts the id as a string' do
      stub_request(:get, "#{base}/game/10270").to_return(status: 200, body: game_page)

      expect(client.game('10270').id).to eq(10270)
    end

    it 'returns nil when HLTB has no such game' do
      stub_request(:get, "#{base}/game/1122").to_return(status: 404, body: 'Not Found')

      expect(client.game(1122)).to be_nil
    end

    it 'raises RateLimitedError on 429' do
      stub_request(:get, "#{base}/game/10270").to_return(status: 429)

      expect { client.game(10270) }.to raise_error(HowLongToBeat::RateLimitedError)
    end

    it 'raises ParseError when the page shape changed' do
      stub_request(:get, "#{base}/game/10270").to_return(status: 200, body: '<html></html>')

      expect { client.game(10270) }.to raise_error(HowLongToBeat::ParseError)
    end
  end
end
