import React from 'react';
import ReactDOM from 'react-dom';
import fetchMock from 'fetch-mock/es5/client';
import HomePage from './HomePage';
import SpecSugar from '../../../../spec/javascripts/support/spec_sugar.jsx';
import {withDefaultNowContext} from '../../../../spec/javascripts/support/NowContainer';
import homeFeedJson from '../../../../spec/javascripts/fixtures/home_feed_json';
import unsupportedLowGradesJson from '../../../../spec/javascripts/fixtures/home_unsupported_low_grades_json';

function testProps() {
  return {
    educatorId: 9999
  };
}

beforeEach(() => {
  fetchMock.restore();
  fetchMock.get('/home/feed_json?educator_id=9999&limit=20&time_now=1520938986', homeFeedJson);
  fetchMock.get('/home/unsupported_low_grades_json?educator_id=9999&limit=100', unsupportedLowGradesJson);
});

it('renders without crashing', () => {
  const props = testProps();
  const el = document.createElement('div');
  ReactDOM.render(withDefaultNowContext(<HomePage {...props} />), el);
});

SpecSugar.withTestEl('integration tests', container => {
  it('renders everything after fetch', done => {
    const props = testProps();
    const el = container.testEl;
    ReactDOM.render(withDefaultNowContext(<HomePage {...props} />), el);
    expect(el.innerHTML).toContain("What's happening?");
    expect(el.innerHTML).toContain("How can we adapt?");

    setTimeout(() => {
      expect(el.innerHTML).toContain('Students to check on');
      expect($(el).find('.EventNoteCard').length).toEqual(19);
      expect($(el).find('.BirthdayCard').length).toEqual(1);
      done();
    }, 0);
  });
});