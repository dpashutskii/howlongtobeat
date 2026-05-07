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

      it 'extracts the current /api/bleed endpoint from a POST fetch call' do
        info = described_class.new(bleed_chunk_shape)
        expect(info.search_url).to eq('api/bleed')
      end

      it 'extracts a hypothetical future endpoint without code changes' do
        future_shape = bleed_chunk_shape.gsub('/api/bleed', '/api/somethingnew')
        info = described_class.new(future_shape)
        expect(info.search_url).to eq('api/somethingnew')
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
        expect(candidates).to include('/api/bleed', '/api/finder')
      end

      it 'deduplicates if discovery returns a known fallback' do
        result = described_class.send(:build_endpoint_candidates, '/api/bleed')
        expect(result.count('/api/bleed')).to eq(1)
      end
    end

    context 'when discovery returned nothing' do
      let(:parsed) { nil }

      it 'returns the historical fallback list with /api/bleed first' do
        expect(candidates.first).to eq('/api/bleed')
      end
    end
  end
end
