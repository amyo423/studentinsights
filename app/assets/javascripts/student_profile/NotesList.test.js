import React from 'react';
import ReactDOM from 'react-dom';
import ReactTestUtils from 'react-addons-test-utils';
import _ from 'lodash';
import moment from 'moment';
import {studentProfile, feedForTestingNotes} from './fixtures/fixtures';
import {withDefaultNowContext} from '../testing/NowContainer';
import NotesList from './NotesList';


function testProps(props = {}) {
  return {
    currentEducatorId: 1,
    feed: feedForTestingNotes,
    educatorsIndex: studentProfile.educatorsIndex,
    onSaveNote: jest.fn(),
    onEventNoteAttachmentDeleted: jest.fn(),
    ...props
  };
}

function feedWithEventNotesJson(eventNotesJson) {
  return {
    transition_notes: [],
    services: {
      active: [],
      discontinued: []
    },
    deprecated: {
      interventions: []
    },
    event_notes: eventNotesJson
  };
}

function testPropsForRestrictedNote(props = {}) {
  return testProps({
    feed: feedWithEventNotesJson([{
      "id": 3,
      "student_id": 5,
      "educator_id": 1,
      "event_note_type_id": 301,
      "text": "RESTRICTED-this-is-the-note-text",
      "recorded_at": "2018-02-26T22:20:55.398Z",
      "created_at": "2018-02-26T22:20:55.416Z",
      "updated_at": "2018-02-26T22:20:55.416Z",
      "is_restricted": true,
      "event_note_revisions_count": 0,
      "attachments": [
        { id: 42, url: "https://www.example.com/studentwork" },
        { id: 47, url: "https://www.example.com/morestudentwork" }
      ]
    }]),
    ...props
  });
}

function testRender(props) {
  const el = document.createElement('div');
  ReactDOM.render(withDefaultNowContext(<NotesList {...props} />), el);
  return el;
}

function readNoteTimestamps(el) {
  return $(el).find('.NoteCard .date').toArray().map(dateEl => {
    return moment.parseZone($(dateEl).text(), 'MMM DD, YYYY').toDate().getTime();
  });
}

it('with full historical data, renders everything on the happy path', () => {
  const el = testRender(testProps({
    defaultSchoolYearsBack: {
      number: 20,
      textYears: 'twenty years'
    }
  }));

  const noteTimestamps = readNoteTimestamps(el);
  expect(_.head(noteTimestamps)).toBeGreaterThan(_.last(noteTimestamps));
  expect(_.sortBy(noteTimestamps).reverse()).toEqual(noteTimestamps);
  expect($(el).find('.NoteCard').length).toEqual(5);

  expect(el.innerHTML).toContain('Behavior Plan');
  expect(el.innerHTML).toContain('Attendance Officer');
  expect(el.innerHTML).toContain('MTSS Meeting');
  expect(el.innerHTML).toContain('Transition note');
  expect(el.innerHTML).not.toContain('SST Meeting');

  // Notes attachments expectations
  expect(el.innerHTML).toContain("https://www.example.com/morestudentwork");
  expect(el.innerHTML).toContain("https://www.example.com/studentwork");
  expect(el.innerHTML).toContain("(remove)");
});

it('limits visible notes by default', () => {
  const el = testRender(testProps());
  expect($(el).find('.NoteCard').length).toEqual(1);
  expect($(el).find('.CleanSlateMessage').length).toEqual(1);
});

it('allows anyone to click and see older notes', () => {
  const el = testRender(testProps());
  expect($(el).find('.NoteCard').length).toEqual(1);
  ReactTestUtils.Simulate.click($(el).find('.CleanSlateMessage a').get(0));
  expect($(el).find('.NoteCard').length).toEqual(5);
});

it('allows editing a note you wrote', () => {
  const el = testRender(testProps({
    currentEducatorId: 1,
    feed: feedWithEventNotesJson([{
      "id": 3,
      "student_id": 5,
      "educator_id": 1,
      "event_note_type_id": 301,
      "text": "hello-text",
      "recorded_at": "2018-02-26T22:20:55.398Z",
      "created_at": "2018-02-26T22:20:55.416Z",
      "updated_at": "2018-02-26T22:20:55.416Z",
      "is_restricted": false,
      "event_note_revisions_count": 0,
      "attachments": []
    }]
  )}));
  expect($(el).find('.NoteText').length).toEqual(0);
  expect($(el).find('.EditableNoteText').length).toEqual(1);
});

it('does not allow editing notes written by someone else', () => {
  const el = testRender(testProps({
    currentEducatorId: 999,
    feed: feedWithEventNotesJson([{
      "id": 3,
      "student_id": 5,
      "educator_id": 1,
      "event_note_type_id": 301,
      "text": "hello-text",
      "recorded_at": "2018-02-26T22:20:55.398Z",
      "created_at": "2018-02-26T22:20:55.416Z",
      "updated_at": "2018-02-26T22:20:55.416Z",
      "is_restricted": false,
      "event_note_revisions_count": 0,
      "attachments": []
    }]
  )}));
  expect($(el).find('.NoteText').length).toEqual(1);
  expect($(el).find('.EditableNoteText').length).toEqual(0);
});

describe('props impacting restricted notes', () => {
  it('by default', () => {
    const el = testRender(testPropsForRestrictedNote());
    expect(el.innerHTML).not.toContain('RESTRICTED-this-is-the-note-text');
    expect(el.innerHTML).toContain('marked this note as restricted');
    expect(el.innerHTML).not.toContain('https://www.example.com/');
  });

  it('for my notes page', () => {
    const el = testRender(testPropsForRestrictedNote());
    expect(el.innerHTML).not.toContain('RESTRICTED-this-is-the-note-text');
    expect(el.innerHTML).not.toContain('https://www.example.com/');
    expect(el.innerHTML).toContain('marked this note as restricted');
  });

  it('for restricted notes page', () => {
    const el = testRender(testPropsForRestrictedNote({
      showRestrictedNoteContent: true,
      allowDirectEditingOfRestrictedNoteText: true
    }));
    expect(el.innerHTML).toContain('RESTRICTED-this-is-the-note-text');
    expect(el.innerHTML).toContain('https://www.example.com/');
    expect(el.innerHTML).not.toContain('marked this note as restricted');
    expect($(el).find('.EditableNoteText').length).toEqual(1);
  });
});
