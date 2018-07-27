import React from 'react';
import PropTypes from 'prop-types';
import moment from 'moment';
import _ from 'lodash';
import * as InsightsPropTypes from '../helpers/InsightsPropTypes';
import {toMomentFromTime} from '../helpers/toMoment';
import LightProfileHeader from './LightProfileHeader';
import LightProfileTab, {LightShoutNumber} from './LightProfileTab';
import AttendanceDetails from './AttendanceDetails';
import ElaDetails from './ElaDetails';
import MathDetails from './MathDetails';
import LightNotesDetails from './LightNotesDetails';
import LightServiceDetails from './LightServiceDetails';
import LightNotesHelpContext from './LightNotesHelpContext';
import StudentSectionsRoster from './StudentSectionsRoster';
import {tags} from './lightTagger';
import {toMoment, toValue} from './QuadConverter';


// Prototype of profile v3
export default class LightProfilePage extends React.Component {
  countEventsBetween(events, daysBack) {
    const {nowMomentFn} = this.props;
    const startMoment = nowMomentFn().startOf('day');
    const endMoment = startMoment.clone().subtract(daysBack, 'days');
    return countEventsBetween(events, startMoment, endMoment);
  }

  onColumnClicked(columnKey) {
    this.props.actions.onColumnClicked(columnKey);
  }

  render() {
    const {student, districtKey, access, transitionNotes, educatorsIndex} = this.props;
    const isHighSchool = (student.school_type === 'HS');
    return (
      <div className="LightProfilePage">
        <LightProfileHeader
          student={student}
          access={access}
          transitionNotes={transitionNotes}
          educatorsIndex={educatorsIndex}
          districtKey={districtKey}
        />
        <div style={styles.tabsContainer}>
          <div style={styles.tabLayout}>{this.renderNotesColumn()}</div>
          {isHighSchool && <div style={styles.tabLayout}>{this.renderGradesColumn()}</div>}
          {!isHighSchool && <div style={styles.tabLayout}>{this.renderReadingColumn()}</div>}
          {!isHighSchool && <div style={styles.tabLayout}>{this.renderMathColumn()}</div>}
          <div style={styles.tabLayout}>{this.renderAttendanceColumn()}</div>
          <div style={styles.tabLayout}>{this.renderBehaviorColumn()}</div>
        </div>
        <div style={styles.detailsContainer}>
          {this.renderSectionDetails()}
        </div>
      </div>
    );
  }

  renderSectionDetails() {
    const {selectedColumnKey} = this.props;
    if (selectedColumnKey === 'notes') return this.renderNotes();
    if (selectedColumnKey === 'grades') return this.renderGrades();
    if (selectedColumnKey === 'reading') return this.renderReading();
    if (selectedColumnKey === 'math') return this.renderMath();
    if (selectedColumnKey === 'attendance') return this.renderAttendance();
    if (selectedColumnKey === 'behavior') return this.renderBehavior();
    return null;
  }

  renderNotesColumn() {
    const {feed, nowMomentFn, selectedColumnKey} = this.props;
    const columnKey = 'notes';
    const topRecentTags = findTopRecentTags(feed.event_notes, nowMomentFn());

    return (
      <LightProfileTab
        style={styles.tab}
        isSelected={selectedColumnKey === columnKey}
        onClick={this.onColumnClicked.bind(this, columnKey)}
        intenseColor="#4A90E2"
        fadedColor="#ededed"
        text="Notes">
          {(topRecentTags.length === 0)
            ? <div>No recent keywords</div>
            : topRecentTags.map(tag => <div key={tag}>“{tag}”</div>)}
        </LightProfileTab>
    );
  }

  renderGradesColumn() {
    const {sections, selectedColumnKey} = this.props;
    const columnKey = 'grades';
    const strugglingSectionsCount = sections.filter(section => section.grade_numeric < 69).length;

    return (
      <LightProfileTab
        style={styles.tab}
        isSelected={selectedColumnKey === columnKey}
        onClick={this.onColumnClicked.bind(this, columnKey)}
        intenseColor="#ff7f00"
        fadedColor="hsl(24, 100%, 92%)"
        text="Grades">
          <LightShoutNumber number={strugglingSectionsCount}>
            <div>courses with a D or F</div>
            <div>right now</div>
          </LightShoutNumber>
        </LightProfileTab>
    );
  }

  renderReadingColumn() {
    const {chartData, nowMomentFn, selectedColumnKey} = this.props;
    const columnKey = 'reading';
    const {nDaysText, percentileText} = latestStar(chartData.star_series_reading_percentile, nowMomentFn());
    return (
      <LightProfileTab
        style={styles.tab}
        isSelected={selectedColumnKey === columnKey}
        onClick={this.onColumnClicked.bind(this, columnKey)}
        intenseColor="#ff7f00"
        fadedColor="hsl(24, 100%, 92%)"
        text="Reading">
          <LightShoutNumber number={percentileText}>
            <div>STAR percentile</div>
            <div>{nDaysText}</div>
          </LightShoutNumber>
        </LightProfileTab>
    );
  }

  renderMathColumn() {
    const {selectedColumnKey, chartData, nowMomentFn} = this.props;
    const columnKey = 'math';
    const {nDaysText, percentileText} = latestStar(chartData.star_series_math_percentile, nowMomentFn());
    return (
      <LightProfileTab
        style={styles.tab}
        isSelected={selectedColumnKey === columnKey}
        onClick={this.onColumnClicked.bind(this, columnKey)}
        intenseColor="#6A2987"
        fadedColor="hsl(237,80%,95%)"
        text="Math">
          <LightShoutNumber number={percentileText}>
            <div>STAR percentile</div>
            <div>{nDaysText}</div>
          </LightShoutNumber>
        </LightProfileTab>
    );
  }

  renderAttendanceColumn() {
    const {selectedColumnKey} = this.props;
    const columnKey = 'attendance';
    const count = this.countEventsBetween(this.props.attendanceData.absences, DAYS_AGO);
    return (
      <LightProfileTab
        style={styles.tab}
        isSelected={selectedColumnKey === columnKey}
        onClick={this.onColumnClicked.bind(this, columnKey)}
        intenseColor="#c8326b"
        fadedColor="#f5e1e8"
        text="Attendance">
          <LightShoutNumber number={count}>
            <div>{count === 1 ? 'absence' : 'absences'}</div>
            <div>last {DAYS_AGO} days</div>
          </LightShoutNumber>
        </LightProfileTab>
    );
  }

  renderBehaviorColumn() {
    const {selectedColumnKey} = this.props;
    const columnKey = 'behavior';
    const count = this.countEventsBetween(this.props.attendanceData.discipline_incidents, DAYS_AGO);

    return (
      <LightProfileTab
        style={styles.tab}
        isSelected={selectedColumnKey === columnKey}
        onClick={this.onColumnClicked.bind(this, columnKey)}
        intenseColor="#31AB39"
        fadedColor="hsl(120,80%,95%)"
        text="Behavior">
          <LightShoutNumber number={count}>
            <div>{count === 1 ? 'discipline incident' : 'discipline incidents'}</div>
            <div>last {DAYS_AGO} days</div>
          </LightShoutNumber>
        </LightProfileTab>
    );
  }

  renderNotes() {
    return (
      <div className="LightProfilePage-notes" style={{display: 'flex', flexDirection: 'row'}}>
        <LightNotesDetails
          student={this.props.student}
          educatorsIndex={this.props.educatorsIndex}
          currentEducator={this.props.currentEducator}
          feed={this.props.feed}
          actions={this.props.actions}
          requests={this.props.requests}
          showingRestrictedNotes={false}
          helpContent={<LightNotesHelpContext />}
          helpTitle="What is a Note?"
          title="Notes"
          noteInProgressText={this.props.noteInProgressText}
          noteInProgressType={this.props.noteInProgressType}
          noteInProgressAttachmentUrls={this.props.noteInProgressAttachmentUrls }/>
        <LightServiceDetails
          student={this.props.student}
          serviceTypesIndex={this.props.serviceTypesIndex}
          educatorsIndex={this.props.educatorsIndex}
          currentEducator={this.props.currentEducator}
          feed={this.props.feed}
          actions={this.props.actions}
          requests={this.props.requests} />
      </div>
    );
  }

  renderGrades() {
    const sections = this.props.sections;

    // If there are no sections, don't generate the student sections roster
    if (!sections || sections.length == 0) return null;

    // If this student is not a high school student, don't generate the student sections roster
    if (this.props.student.school_type != 'HS') return null;

    return (
      <div id="sections-roster" className="roster" style={styles.roundedBox}>
        <h4 style={styles.sectionsRosterTitle}>
          Sections
        </h4>
        <StudentSectionsRoster
          sections={this.props.sections}
          linkableSections={this.props.currentEducatorAllowedSections}
          />
      </div>

    );
  }

  renderReading() {
    return (
      <ElaDetails
        className="LightProfilePage-ela"
        hideNavbar={true}
        chartData={this.props.chartData}
        student={this.props.student} />
    );
  }

  renderMath() {
    return (
      <MathDetails
        className="LightProfilePage-math"
        hideNavbar={true}
        chartData={this.props.chartData}
        student={this.props.student} />
    );
  }

  renderAttendance() {
    return (
      <AttendanceDetails
        className="LightProfilePage-attendance"
        hideNavbar={true}
        disciplineIncidents={this.props.attendanceData.discipline_incidents}
        absences={this.props.attendanceData.absences}
        tardies={this.props.attendanceData.tardies}
        student={this.props.student}
        feed={this.props.feed}
        serviceTypesIndex={this.props.serviceTypesIndex} />
    );
  }

  renderBehavior() {
    return (
      <AttendanceDetails
        className="LightProfilePage-attendance"
        hideNavbar={true}
        disciplineIncidents={this.props.attendanceData.discipline_incidents}
        absences={this.props.attendanceData.absences}
        tardies={this.props.attendanceData.tardies}
        student={this.props.student}
        feed={this.props.feed}
        serviceTypesIndex={this.props.serviceTypesIndex} />
    );
  }
}
LightProfilePage.propTypes = {
  // UI
  selectedColumnKey: PropTypes.string.isRequired,

  // context
  nowMomentFn: PropTypes.func.isRequired,
  currentEducator: PropTypes.shape({
    labels: PropTypes.arrayOf(PropTypes.string).isRequired
  }).isRequired,
  districtKey: PropTypes.string.isRequired,

  // constants
  educatorsIndex: PropTypes.object.isRequired,
  serviceTypesIndex: PropTypes.object.isRequired,

  // data
  student: PropTypes.object.isRequired,
  feed: PropTypes.object.isRequired,
  transitionNotes: PropTypes.array.isRequired,
  dibels: PropTypes.array.isRequired,
  chartData: PropTypes.shape({
    // ela
    most_recent_star_reading_percentile: PropTypes.number,
    most_recent_mcas_ela_scaled: PropTypes.number,
    most_recent_mcas_ela_growth: PropTypes.number,
    star_series_reading_percentile: PropTypes.array,
    mcas_series_ela_scaled: PropTypes.array,
    mcas_series_ela_growth: PropTypes.array,
    // math
    most_recent_star_math_percentile: PropTypes.number,
    most_recent_mcas_math_scaled: PropTypes.number,
    most_recent_mcas_math_growth: PropTypes.number,
    star_series_math_percentile: PropTypes.array,
    mcas_series_math_scaled: PropTypes.array,
    mcas_series_math_growth: PropTypes.array
  }),
  attendanceData: PropTypes.shape({
    discipline_incidents: PropTypes.array,
    tardies: PropTypes.array,
    absences: PropTypes.array
  }),
  noteInProgressText: PropTypes.string.isRequired,
  noteInProgressType: PropTypes.number,
  noteInProgressAttachmentUrls: PropTypes.arrayOf(
    PropTypes.string
  ).isRequired,
  access: PropTypes.object,
  iepDocument: PropTypes.object,
  sections: PropTypes.array,
  currentEducatorAllowedSections: PropTypes.array,

  // flux-y bits
  requests: InsightsPropTypes.requests,
  actions: InsightsPropTypes.actions
};


const styles = {
  tabsContainer: {
    display: 'flex',
    flexDirection: 'row',
    alignItems: 'stretch',
    margin: 20,
    flex: 1
  },
  tabLayout: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column'
  },
  tab: {
    flex: 1,
    textAlign: 'center'
  },
  detailsContainer: {
    margin: 20
  }
};



function findTopRecentTags(eventNotes, nowMoment) {
  const thresholdInDays = 100000; // should be 45, this is for testing locally, where dates are busted
  const recentNotes = eventNotes.filter(e => nowMoment.clone().diff(toMomentFromTime(e.recorded_at), 'days') < thresholdInDays);
  const recentNotesText = recentNotes.map(e => e.text).join(' ');
  const recentTags = tags(recentNotesText);
  return recentTags.slice(0, 4);
}


function countEventsBetween(events, startMoment, endMoment) {
  return events.filter(event => {
    return moment.utc(event.occurred_at).isBetween(startMoment, endMoment);
  }).length;
}

const DAYS_AGO = 45;


function latestStar(sortedQuads, nowMoment) {
  const quad = _.last(sortedQuads);
  if (!quad) return {
    nDaysText: 'not yet taken',
    percentileText: '-'
  };

  const testMoment = toMoment(quad);
  const nDaysText = testMoment.from(nowMoment);
  const percentile = toValue(quad);
  const percentileText = (percentile)
    ? percentileWithSuffix(percentile)
    : '-';
  return {nDaysText, percentileText};
}

function percentileWithSuffix(percentile) {
  const lastDigit = _.last(percentile.toString());
  const suffix = {
    1: 'st',
    2: 'nd',
    3: 'rd'
  }[lastDigit] || 'th';
  return `${percentile}${suffix}`;
}