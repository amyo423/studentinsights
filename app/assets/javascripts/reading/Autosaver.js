import React from 'react';
import PropTypes from 'prop-types';
import _ from 'lodash';

// Autosaves on a throttled interval, calling `doSaveFn` whenever `readSnapshotFn`
// has changed (using _.isEqual).
export default class Autosaver extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      lastSavedSnapshot: null
    };

    this.doAutoSaveChanges = _.throttle(this.doAutoSaveChanges, props.autoSaveIntervalMs);
    this.onPostDone = this.onPostDone.bind(this);
    this.onPostError = this.onPostError.bind(this);
  }

  componentDidUpdate() {
    this.doAutoSaveChanges();
  }

  componentWillUnmount() {
    if (this.doAutoSaveChanges.flush) this.doAutoSaveChanges.flush(); // flush any queued changes
  }

  isDirty() {
    const {readSnapshotFn} = this.props;
    const {lastSavedSnapshot} = this.state;
    const snapshot = readSnapshotFn();
    if (snapshot === undefined || snapshot === null) return false;
    return !_.isEqual(lastSavedSnapshot, snapshot);
  }

  // This method is throttled.
  doAutoSaveChanges() {
    const {doSaveFn} = this.props;
    if (!this.isDirty()) return;

    doSaveFn()
      .then(this.onPostDone)
      .catch(this.onPostError);
  }

  onPostDone(snapshotForSaving) {
    this.setState({lastSavedSnapshot: snapshotForSaving});
  }

  onPostError(error) {
    window.Rollbar.error && window.Rollbar.error('Autosaver#onPostError', error);
  }

  render() {
    const {children} = this.props;
    return children;
  }
}
Autosaver.propTypes = {
  readSnapshotFn: PropTypes.func.isRequired,
  doSaveFn: PropTypes.func.isRequired,
  children: PropTypes.node.isRequired,
  autoSaveIntervalMs: PropTypes.number.isRequired
};
