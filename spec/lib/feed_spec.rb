require 'spec_helper'

def test_card(date_text)
  timestamp = Time.parse(date_text)
  FeedCard.new(:event_note, timestamp, {foo: 'bar'})
end

def seed_event_notes(pals)

end

RSpec.describe Feed do
  let!(:pals) { TestPals.create! }
  let!(:time_now) { pals.time_now }

  describe '#merge_sort_and_limit_cards' do
    it 'works correctly' do
      card_sets = [
        [test_card('3/5'), test_card('3/7'), test_card('3/9')],
        [test_card('3/4'), test_card('3/5'), test_card('3/8')],
        [test_card('3/1'), test_card('3/2'), test_card('3/6')]
      ]
      feed = Feed.new(pals.shs_jodi)
      expect(feed.merge_sort_and_limit_cards(card_sets, 2).as_json).to eq [
        {"type"=>"event_note", "timestamp"=>'2018-03-09T00:00:00.000-05:00', "json"=>{"foo"=>"bar"}},
        {"type"=>"event_note", "timestamp"=>'2018-03-08T00:00:00.000-05:00', "json"=>{"foo"=>"bar"}}
      ]
    end
  end

  describe '#event_note_cards' do
    it 'works correctly' do
      event_note = EventNote.create!(
        student: pals.shs_freshman_mari,
        educator: pals.uri,
        event_note_type: EventNoteType.find(305),
        text: 'blah',
        recorded_at: time_now - 7.days
      )
      feed = Feed.new(pals.shs_jodi)
      cards = feed.event_note_cards(time_now, 4)
      expect(cards.size).to eq 1
      expect(cards.first.type).to eq(:event_note_card)
      expect(cards.first.timestamp).to eq(time_now - 7.days)
      expect(cards.first.json['id']).to eq(event_note.id)
    end

    it 'never shows restricted notes, even if access' do
      event_note = EventNote.create!(
        is_restricted: true,
        student: pals.shs_freshman_mari,
        educator: pals.uri,
        event_note_type: EventNoteType.find(305),
        text: 'blah',
        recorded_at: time_now - 7.days
      )
      feed = Feed.new(pals.uri)
      cards = feed.event_note_cards(time_now, 4)
      expect(cards.size).to eq 0
    end
  end

  describe '#birthday_cards' do
    it 'works correctly' do
      feed = Feed.new(pals.shs_jodi)
      cards = feed.birthday_cards(time_now, 4)
      expect(cards.size).to eq 1
      expect(cards.first.type).to eq(:birthday_card)
      expect(cards.first.timestamp.to_date).to eq(Date.parse('2018-03-12'))
      expect(cards.first.json['id']).to eq(pals.shs_freshman_mari.id)
    end
  end
end