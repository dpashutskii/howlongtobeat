require 'spec_helper'

RSpec.describe HowLongToBeat::HowLongToBeat do
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
