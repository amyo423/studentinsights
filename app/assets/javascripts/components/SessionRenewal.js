import React from 'react';
import PropTypes from 'prop-types';
import {apiFetchJson} from '../helpers/apiFetchJson';


// Show a warning that the user's session is likely to timeout shortly.
// This will be reset by Ajax calls or single-page navigation, so isn't entirely
// accurate and will warn a bit too aggressively.  But it will work well for full-page
// loads without other interactions.
export default class SessionRenewal extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      status: States.ACTIVE
    };
    this.warningTimer = null;
    this.timeoutTimer = null;

    this.resetTimers = this.resetTimers.bind(this);
    this.onWarning = this.onWarning.bind(this);
    this.onTimeout = this.onTimeout.bind(this);
    this.onRenewClicked = this.onRenewClicked.bind(this);
    this.onRenewCompleted = this.onRenewCompleted.bind(this);
  }

  // Provides a function for child components to reset session timers (eg, on xhr requests).
  getChildContext() {
    return {resetTimers: this.resetTimers};
  }

  componentDidMount() {
    this.resetTimers();
  }

  resetTimers() {
    const {warningTimeoutInSeconds, sessionTimeoutInSeconds} = this.props;
    if (this.warningTimer) clearTimeout(this.warningTimer);
    if (this.timeoutTimer) clearTimeout(this.timeoutTimer);

    this.warningTimer = setTimeout(this.onWarning, warningTimeoutInSeconds * 1000);
    this.timeoutTimer = setTimeout(this.onTimeout, sessionTimeoutInSeconds * 1000);
  }

  // At this point, any transient data in the browser will be rejected by the server.
  // If the server session has expired, this will redirect to the sign in page, clearing the
  // screen of student data.  If it's still valid (from activities in other tabs, nothing will change).
  forceReload() {
    const {forceReload} = this.props;
    if (forceReload) {
      forceReload();
    } else {
      window.location.reload(true);
    }
  }

  onWarning() {
    this.setState({status: States.WARNING});
  }

  onTimeout() {
    this.setState({status: States.TIMED_OUT});
    this.forceReload();
  }

  onError() {
    this.setState({status: States.ERROR});
    this.resetTimers();
    this.forceReload();
  }

  onRenewClicked(e) {
    e.preventDefault();
    apiFetchJson('/educators/reset').then(this.onRenewCompleted);
  }

  onRenewCompleted(json) {
    if (json.status ==='ok') {
      this.resetTimers();
      this.setState({status: States.ACTIVE});
    } else {
      this.onError();  
    }
  }

  render() {
    const {status} = this.state;
    if (status === States.ACTIVE) return null;
    
    if (status === States.WARNING) return (
      <div style={styles.root}>
        Please click <a href="#" style={styles.link} onClick={this.onRenewClicked}>this link</a> or your session will timeout due to inactivity.
      </div>
    );

    if (status === States.TIMED_OUT) return (
      <div style={styles.root}>Your session has timed out due to inactivity.</div>
    );

    if (status === States.ERROR) return (
      <div style={styles.root}>Your session could not be renewed, please sign in again.</div>
    );
  }
}
SessionRenewal.childContextTypes = {
  resetTimers: PropTypes.func
};
SessionRenewal.propTypes = {
  warningTimeoutInSeconds: PropTypes.number.isRequired,
  sessionTimeoutInSeconds: PropTypes.number.isRequired,
  forceReload: PropTypes.func
};

const styles = {
  root: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    backgroundColor: '#4A90E2',
    color: 'white',
    textAlign: 'center',
    padding: 20
  },
  link: {
    color: 'white',
    textDecoration: 'underline',
    fontSize: 16
  }
};

const States = {
  ACTIVE: 'active',
  WARNING: 'warning',
  TIMED_OUT: 'timed_out'
};