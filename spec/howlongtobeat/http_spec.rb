require 'spec_helper'

RSpec.describe HowLongToBeat::Http do
  let(:url) { 'https://howlongtobeat.com/game/10270' }
  let(:clock) { [100.0] }
  let(:sleeps) { [] }
  let(:http) do
    described_class.new(
      min_interval: 2.0,
      clock: -> { clock.first },
      sleeper: ->(seconds) { sleeps << seconds; clock[0] += seconds }
    )
  end

  it 'returns code and body for a 2xx response' do
    stub_request(:get, url).to_return(status: 200, body: 'page')

    expect(http.get(url)).to have_attributes(code: 200, body: 'page')
  end

  it 'returns a 404 as a response so callers can treat it as not found' do
    stub_request(:get, url).to_return(status: 404, body: 'missing')

    expect(http.get(url).code).to eq(404)
  end

  it 'raises RateLimitedError on 429' do
    stub_request(:get, url).to_return(status: 429, body: '{"error":"Too many requests"}')

    expect { http.get(url) }.to raise_error(HowLongToBeat::RateLimitedError, /429/)
  end

  it 'raises RequestError on a 5xx' do
    stub_request(:get, url).to_return(status: 503)

    expect { http.get(url) }.to raise_error(HowLongToBeat::RequestError, /503/)
  end

  it 'carries the HTTP status on RequestError' do
    stub_request(:get, url).to_return(status: 503)

    expect { http.get(url) }.to raise_error(HowLongToBeat::RequestError) { |error|
      expect(error.status).to eq(503)
    }
  end

  it 'leaves the status nil for a network failure' do
    stub_request(:get, url).to_timeout

    expect { http.get(url) }.to raise_error(HowLongToBeat::RequestError) { |error|
      expect(error.status).to be_nil
    }
  end

  it 'raises RequestError on a 403' do
    stub_request(:get, url).to_return(status: 403)

    expect { http.get(url) }.to raise_error(HowLongToBeat::RequestError, /403/)
  end

  it 'raises RequestError on a redirect instead of following it' do
    stub_request(:get, url).to_return(status: 302, headers: { 'Location' => 'https://example.com' })

    expect { http.get(url) }.to raise_error(HowLongToBeat::RequestError, /302/)
  end

  it 'raises RequestError on a timeout' do
    stub_request(:get, url).to_timeout

    expect { http.get(url) }.to raise_error(HowLongToBeat::RequestError, /failed/)
  end

  it 'raises RequestError when the body cannot be decompressed' do
    stub_request(:get, url).to_raise(Zlib::DataError.new('incorrect header check'))

    expect { http.get(url) }.to raise_error(HowLongToBeat::RequestError, /Zlib::DataError/)
  end

  it 'sends the fixed browser User-Agent' do
    stub_request(:get, url).to_return(status: 200)

    http.get(url)

    expect(a_request(:get, url).with(headers: { 'User-Agent' => described_class::USER_AGENT })).to have_been_made
  end

  it 'lets callers override headers' do
    stub_request(:get, url).to_return(status: 200)

    http.get(url, 'Accept' => 'application/json')

    expect(a_request(:get, url).with(headers: { 'Accept' => 'application/json' })).to have_been_made
  end

  it 'posts the body' do
    stub_request(:post, 'https://howlongtobeat.com/api/search/site').with(body: '{"q":1}').to_return(status: 200, body: '[]')

    expect(http.post('https://howlongtobeat.com/api/search/site', {}, '{"q":1}').body).to eq('[]')
  end

  it 'waits until min_interval has passed since the previous request' do
    stub_request(:get, url).to_return(status: 200)

    http.get(url)
    clock[0] += 0.5
    http.get(url)

    expect(sleeps).to eq([1.5])
  end

  it 'does not wait when the gap is already long enough' do
    stub_request(:get, url).to_return(status: 200)

    http.get(url)
    clock[0] += 5
    http.get(url)

    expect(sleeps).to be_empty
  end

  it 'counts a failed request towards pacing' do
    stub_request(:get, url).to_return(status: 503).then.to_return(status: 200)

    expect { http.get(url) }.to raise_error(HowLongToBeat::RequestError)
    http.get(url)

    expect(sleeps).to eq([2.0])
  end

  it 'disables Net::HTTP max_retries to prevent unplaced retries' do
    stub_request(:get, url).to_return(status: 200)

    expect(Net::HTTP).to receive(:start).with(
      'howlongtobeat.com', 443,
      hash_including(max_retries: 0, open_timeout: 5, read_timeout: 10)
    ).and_call_original

    http.get(url)
  end
end
