import React from 'react';
import PropTypes from 'prop-types';
import {apiPutJson} from '../helpers/apiFetchJson';
import FeedView from './FeedView';


// Wraps FeedView with mutable state and an operation
// for event cards to be marked as restricted.
export default class MutableFeedView extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      feedCards: props.defaultFeedCards
    };

    this.cardPropsFn = this.cardPropsFn.bind(this);
  }

  cardPropsFn(type, json) {
    const {educatorLabels} = this.props;
    if (educatorLabels.indexOf('can_mark_notes_as_restricted') === -1) return {};
    if (type !== 'event_note_card') return {};

    return {
      iconsEl: this.renderIconsEl(json.id)
    };
  }

  onClickMarkRestricted(eventNoteId, e) {
    e.preventDefault();
    if (!confirm("Marking this note as restricted will protect the student's privacy,\nwhile also limiting which educators can access this information.\n\nIf you need to undo this, you can email help@studentinsights.org.\n\nContinue?")) return;

    // Make server request optimistically
    apiPutJson(`/api/event_notes/${eventNoteId}/mark_as_restricted`)
      .catch(err => alert('There was an error trying to update the note.  help@studentinsights.org has been sent a notification.'));

    // Remove from UI now
    const {feedCards} = this.state;
    const feedCardsWithout = feedCards.filter(feedCard => {
      if ((feedCard.type === 'event_note_card') && (feedCard.json.id === eventNoteId)) return false;
      return true;
    });
    this.setState({feedCards: feedCardsWithout});
  }

  render() {
    const {feedCards} = this.state;
    return (
      <FeedView
        feedCards={feedCards}
        cardPropsFn={this.cardPropsFn}
      />
    );
  }

  renderIconsEl(eventNoteId) {
    return (
      <div className="RestrictedBits">
        <a href="#" style={styles.link} onClick={this.onClickMarkRestricted.bind(this, eventNoteId)}>
          Mark restricted
        </a>
      </div>
    );
  }
}
MutableFeedView.propTypes = {
  defaultFeedCards: PropTypes.array.isRequired,
  educatorLabels: PropTypes.arrayOf(PropTypes.string).isRequired
};

const styles = {
  link: {
    color: '#ccc'
  }
};
