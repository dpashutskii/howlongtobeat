require 'spec_helper'

RSpec.describe HowLongToBeat::HTMLRequests do
  describe HowLongToBeat::HTMLRequests::SearchInfo do
    describe '#search_url' do
      # Real shape captured from HLTB's Turbopack chunk on 2026-05-07.
      # If HLTB rotates the endpoint name again, this fixture should be updated
      # to the new shape and the tests should still pass without code changes.
      let(:bleed_chunk_shape) do
        <<~JS
          ...he:!(u?.user_id>0)};a&&(s[a]=l);let i=await fetch("/api/bleed",{method:"POST",headers:{"Content-Type":"application/json","x-auth-token":t,"x-hp-key":a,"x-hp-val":l},body:JSON.stringify(s)});if(403===i.status&&!e){...
        JS
      end

      # Real shape captured from HLTB's Turbopack chunk on 2026-09-04.
      # The endpoint moved to a nested path: /api/bleed -> /api/search/site.
      let(:search_site_chunk_shape) do
        <<~JS
          ...he:!(u?.user_id>0)};a&&(s[a]=r);let i=await fetch("/api/search/site",{method:"POST",headers:{"Content-Type":"application/json","x-auth-token":t,"x-hp-key":a,"x-hp-val":r},body:JSON.stringify(s)});if(403===i.status&&!e){...
        JS
      end

      # Another real chunk from the same bundle: a POST fetch that is NOT the
      # search endpoint. It carries no x-auth-token header.
      let(:error_chunk_shape) do
        'fetch("/api/error",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:e,user:t,custom:n})})'
      end

      it 'extracts the /api/bleed endpoint from a POST fetch call' do
        info = described_class.new(bleed_chunk_shape)
        expect(info.search_url).to eq('api/bleed')
      end

      it 'keeps the full nested path for the current /api/search/site endpoint' do
        info = described_class.new(search_site_chunk_shape)
        expect(info.search_url).to eq('api/search/site')
      end

      it 'extracts a hypothetical future nested endpoint without code changes' do
        future_shape = search_site_chunk_shape.gsub('/api/search/site', '/api/finder/v2')
        info = described_class.new(future_shape)
        expect(info.search_url).to eq('api/finder/v2')
      end

      it 'prefers the authenticated POST fetch when a script has several POST fetches' do
        info = described_class.new(error_chunk_shape + "\n" + search_site_chunk_shape)
        expect(info.search_url).to eq('api/search/site')
      end

      it 'returns nil when no POST fetch to /api/* is present' do
        info = described_class.new('var x = 1; console.log("hello")')
        expect(info.search_url).to be_nil
      end

      it 'ignores GET fetches to /api/*' do
        get_only = 'fetch("/api/bleed",{method:"GET"})'
        info = described_class.new(get_only)
        expect(info.search_url).to be_nil
      end
    end

    describe '#authenticated?' do
      it 'is true when the matched POST fetch sends x-auth-token' do
        info = described_class.new('fetch("/api/search/site",{method:"POST",headers:{"x-auth-token":t}})')
        expect(info).to be_authenticated
      end

      it 'is false when the matched POST fetch has no x-auth-token' do
        info = described_class.new('fetch("/api/error",{method:"POST",headers:{"Content-Type":"application/json"}})')
        expect(info).not_to be_authenticated
      end
    end

    describe '#api_key' do
      it 'extracts a userId from the search payload shape' do
        script = 'searchOptions:{users:{id:"abc123def",sortCategory:"postcount"}}'
        info = described_class.new(script)
        expect(info.api_key).to eq('abc123def')
      end

      it 'returns nil when neither pattern matches' do
        info = described_class.new('completely unrelated content')
        expect(info.api_key).to be_nil
      end
    end
  end

  describe '.send_website_request_getcode' do
    # Stub the network layer so we can control which chunks the homepage
    # references and in what order.
    let(:homepage) do
      <<~HTML
        <html><head>
          <script src="/_next/static/chunks/error.js"></script>
          <script src="/_next/static/chunks/search.js"></script>
        </head></html>
      HTML
    end
    let(:error_chunk) do
      'fetch("/api/error",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:e})})'
    end
    let(:search_chunk) do
      'fetch("/api/search/site",{method:"POST",headers:{"Content-Type":"application/json","x-auth-token":t,"x-hp-key":a,"x-hp-val":r},body:JSON.stringify(s)})'
    end

    before do
      allow(described_class).to receive(:make_get_request) do |url, _headers|
        case url
        when HowLongToBeat::HTMLRequests::BASE_URL then homepage
        when %r{/error\.js\z} then error_chunk
        when %r{/search\.js\z} then search_chunk
        end
      end
    end

    it 'skips a non-search POST fetch chunk that appears before the search chunk' do
      info = described_class.send(:send_website_request_getcode)
      expect(info.search_url).to eq('api/search/site')
    end

    it 'falls back to the first POST fetch when no chunk is authenticated' do
      allow(described_class).to receive(:make_get_request) do |url, _headers|
        case url
        when HowLongToBeat::HTMLRequests::BASE_URL then homepage
        when %r{/error\.js\z} then error_chunk
        when %r{/search\.js\z} then 'var noop = 1;'
        end
      end
      info = described_class.send(:send_website_request_getcode)
      expect(info.search_url).to eq('api/error')
    end
  end

  describe '.build_endpoint_candidates' do
    # Private method — exercise via .send to keep the test focused on the
    # ordering contract that callers depend on.
    let(:candidates) { described_class.send(:build_endpoint_candidates, parsed) }

    context 'when discovery returned a value' do
      let(:parsed) { '/api/something' }

      it 'puts the discovered endpoint first' do
        expect(candidates.first).to eq('/api/something')
      end

      it 'still includes known historical fallbacks after the discovered one' do
        expect(candidates).to include('/api/search/site', '/api/bleed', '/api/finder')
      end

      it 'deduplicates if discovery returns a known fallback' do
        result = described_class.send(:build_endpoint_candidates, '/api/search/site')
        expect(result.count('/api/search/site')).to eq(1)
      end
    end

    context 'when discovery returned nothing' do
      let(:parsed) { nil }

      it 'returns the historical fallback list with /api/search/site first' do
        expect(candidates.first).to eq('/api/search/site')
      end
    end
  end
end
