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

  describe '#search' do
    let(:homepage) do
      '<html><head><script src="/_next/static/chunks/consent.js"></script>' \
        '<script src="/_next/static/chunks/error.js"></script>' \
        '<script src="/_next/static/chunks/search.js"></script></head></html>'
    end
    let(:error_chunk) { 'fetch("/api/error",{method:"POST",headers:{"Content-Type":"application/json"}})' }
    let(:search_chunk) do
      'let i=await fetch("/api/search/site",{method:"POST",headers:{"Content-Type":"application/json",' \
        '"x-auth-token":t,"x-hp-key":a,"x-hp-val":r},body:JSON.stringify(s)});'
    end
    let(:init_url) { %r{\Ahttps://howlongtobeat\.com/api/search/site/init\?t=\d+\z} }
    let(:results_json) { { data: [{ game_id: 80569, game_name: 'Haven', release_world: 2020, comp_main: 38820 }] }.to_json }

    before do
      stub_request(:get, base).to_return(status: 200, body: homepage)
      stub_request(:get, "#{base}/_next/static/chunks/consent.js").to_return(status: 302)
      stub_request(:get, "#{base}/_next/static/chunks/error.js").to_return(status: 200, body: error_chunk)
      stub_request(:get, "#{base}/_next/static/chunks/search.js").to_return(status: 200, body: search_chunk)
      stub_request(:get, init_url).to_return(status: 200, body: '{"token":"tok","hpKey":"k1","hpVal":"v1"}')
      stub_request(:post, "#{base}/api/search/site").to_return(status: 200, body: results_json)
    end

    it 'returns the search rows' do
      expect(client.search('Haven').map(&:name)).to eq(['Haven'])
    end

    it 'sends the token and hp key/value from /init' do
      client.search('Haven')

      expect(a_request(:post, "#{base}/api/search/site")
        .with(headers: { 'x-auth-token' => 'tok', 'x-hp-key' => 'k1', 'x-hp-val' => 'v1' })).to have_been_made
    end

    it 'skips a broken chunk and stops at the authenticated search chunk' do
      client.search('Haven')

      expect(a_request(:get, "#{base}/_next/static/chunks/search.js")).to have_been_made.once
    end

    it 'discovers the endpoint once and reuses it within the hour' do
      client.search('Haven')
      clock[0] += 120
      client.search('Haven')

      expect(a_request(:get, base)).to have_been_made.once
    end

    it 'rediscovers the endpoint after an hour' do
      client.search('Haven')
      clock[0] += 3601
      client.search('Haven')

      expect(a_request(:get, base)).to have_been_made.twice
    end

    it 'reuses the token for 60 seconds' do
      client.search('Haven')
      clock[0] += 30
      client.search('Haven')
      clock[0] += 31
      client.search('Haven')

      expect(a_request(:get, init_url)).to have_been_made.twice
    end

    it 'waits before the first search with a new token' do
      client.search('Haven')

      expect(sleeps).to include(1.2)
    end

    it 'raises RateLimitedError on a 429 from /init without trying other endpoints' do
      stub_request(:get, init_url).to_return(status: 429)
      stub_request(:get, %r{/api/bleed/init})

      expect { client.search('Haven') }.to raise_error(HowLongToBeat::RateLimitedError)
      expect(a_request(:get, %r{/api/bleed/init})).not_to have_been_made
    end

    it 'raises RateLimitedError on a 429 from the search itself' do
      stub_request(:post, "#{base}/api/search/site").to_return(status: 429)

      expect { client.search('Haven') }.to raise_error(HowLongToBeat::RateLimitedError)
    end

    it 'rediscovers once when the search endpoint starts returning 404' do
      renamed_chunk = search_chunk.sub('/api/search/site', '/api/find/v3')
      stub_request(:get, "#{base}/_next/static/chunks/search.js")
        .to_return({ status: 200, body: search_chunk }, { status: 200, body: renamed_chunk })
      stub_request(:post, "#{base}/api/search/site").to_return(status: 404)
      stub_request(:get, %r{\Ahttps://howlongtobeat\.com/api/find/v3/init\?t=\d+\z})
        .to_return(status: 200, body: '{"token":"tok2"}')
      stub_request(:post, "#{base}/api/find/v3").to_return(status: 200, body: results_json)

      expect(client.search('Haven').map(&:id)).to eq([80569])
    end

    it 'raises RequestError when the endpoint still 404s after rediscovery' do
      stub_request(:post, "#{base}/api/search/site").to_return(status: 404)

      expect { client.search('Haven') }.to raise_error(HowLongToBeat::RequestError, /404/)
    end

    it 'falls back to known endpoint names when no chunk is the search call' do
      stub_request(:get, base).to_return(status: 200, body: '<html></html>')

      expect(client.search('Haven').size).to eq(1)
    end

    it 'raises RequestError when no endpoint can be found' do
      stub_request(:get, base).to_return(status: 200, body: '<html></html>')
      stub_request(:get, %r{/api/.+/init}).to_return(status: 404)

      expect { client.search('Haven') }.to raise_error(HowLongToBeat::RequestError, /discover/)
    end

    it 'returns the raw body from search_json' do
      expect(client.search_json('Haven')).to eq(results_json)
    end
  end
end
