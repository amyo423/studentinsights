import React from 'react';
import _ from 'lodash';
import Select from 'react-select';
import 'react-select/dist/react-select.css';
import {gradeText} from '../helpers/gradeText';
import Loading from '../components/Loading';
import IntroCopy from './IntroCopy';
import CreateYourLists from './CreateYourLists';
import HorizontalStepper from './HorizontalStepper';
import {fetchProfile} from './api';



// This is the UI component for grade-level teaching teams to go through the process
// of creating classroom lists.  It tracks all changes and passes them up to callbacks,
// and hands off to other UI components that handle stepping through the process
// and screens for each step.
export default class ClassListCreatorWorkflow extends React.Component {
  constructor(props) {
    super(props);

    this.renderStepContents = this.renderStepContents.bind(this);
  }

  render() {
    const {steps, stepIndex, availableSteps, onStepChanged, isEditable} = this.props;

    return (
      <div className="ClassListCreatorView" style={styles.root}>
        <HorizontalStepper
          steps={steps}
          availableSteps={availableSteps}
          isEditable={isEditable}
          stepIndex={stepIndex}
          onStepChanged={onStepChanged}
          renderFn={this.renderStepContents}
          style={styles.horizontalStepper}
          contentStyle={styles.horizontalStepperContent} />
      </div>
    );
  }

  renderStepContents(stepIndex, step) {
    if (stepIndex === 0) return this.renderChooseYourGrade();
    if (stepIndex === 1) return this.renderMakeAPlan();
    if (stepIndex === 2) return this.renderCreateYourClassrooms();
    if (stepIndex === 3) return this.renderReviewAndShareNotes();
    if (stepIndex === 4) return this.renderShareWithPrincipal();
  }

  renderChooseYourGrade() {
    const {
      isEditable,
      schools,
      gradeLevelsNextYear,
      schoolId,
      gradeLevelNextYear,
      onSchoolIdChanged,
      onGradeLevelNextYearChanged
    } = this.props;

    if (schools === null || gradeLevelsNextYear === null) return <Loading />;
    return (
      <div style={styles.stepContent}>
        <div>
          <div style={styles.heading}>Why are we doing this?</div>
          <IntroCopy />
        </div>
        <div>
          <div>
            <div style={styles.heading}>What school?</div>
              <Select
                name="select-school-name"
                value={schoolId}
                onChange={item => onSchoolIdChanged(item.value)}
                disabled={!isEditable}
                options={_.sortBy(schools, s => s.name).map(school => {
                  return {
                    value: school.id,
                    label: school.name
                  };
                })}
              />
          </div>
          <div>
            <div style={styles.heading}>What grade level are you creating?</div>
              <Select
                name="select-grade-level"
                value={gradeLevelNextYear}
                onChange={item => onGradeLevelNextYearChanged(item.value)}
                disabled={!isEditable}
                options={gradeLevelsNextYear.map(gradeLevelNextYear => {
                  return {
                    value: gradeLevelNextYear,
                    label: `Next year's ${gradeText(gradeLevelNextYear)} ` 
                  };
                })}
              />
          </div>
        </div>
      </div>
    );
  }

  renderMakeAPlan() {
    const {
      isEditable,
      educators,
      authors,
      students,
      gradeLevelNextYear,
      classroomsCount,
      planText,
      onEducatorsChanged,
      onClassroomsCountIncremented,
      onPlanTextChanged
    } = this.props;

    if (educators === null || students === null) return <Loading />;
    return (
      <div style={styles.stepContent}>
        <div>
          <div style={styles.heading}>Who's the team creating these class lists?</div>
          <Select
            name="select-educators"
            multi
            removeSelected
            value={authors}
            valueKey="id"
            labelKey="full_name"
            options={educators}
            onChange={onEducatorsChanged}
            disabled={!isEditable}
          />
        </div>
        <div>
          <div style={styles.heading}>How many {gradeText(gradeLevelNextYear)} classrooms will you create?</div>
          <div style={{marginLeft: 5, display: 'inline-block'}}>
            <button
              style={styles.incrementButton}
              disabled={classroomsCount <= 2 || !isEditable}
              onClick={() => onClassroomsCountIncremented(-1)}>
              -
            </button>
            <div style={{display: 'inline-block', padding: 10}}>{classroomsCount} classrooms</div>
            <button
              style={styles.incrementButton}
              disabled={classroomsCount >= 5 || !isEditable}
              onClick={() => onClassroomsCountIncremented(1)}>
              +
            </button>
          </div>
          <div style={{display: 'inline-block', fontSize: 12, marginLeft: 20}}>With {students.length} students total, this makes the <b>average class size {Math.ceil(students.length / classroomsCount)} students</b>.</div>
        </div>
        <div>
          <div style={styles.heading}>What's your plan for creating classroom communitites?</div>
          <div style={{fontSize: 12, padding: 10, paddingLeft: 0, paddingTop: 3}}>
            Some teams start with considering social dynamics, splitting up students who are leaders or who don't work well together.  Others start creating groups with diverse academic strengths.
          </div>
          <div>
            <textarea
              style={styles.textarea}
              disabled={!isEditable}
              rows={8}
              value={planText}
              onChange={event => onPlanTextChanged(event.target.value)} />
          </div>
        </div>
      </div>
    );
  }

  renderCreateYourClassrooms() {    
    const {
      workspaceId,
      isEditable,
      students,
      classroomsCount,
      onClassListsChanged,
      studentIdsByRoom,
      gradeLevelNextYear
    } = this.props;

    if (students === null || studentIdsByRoom === null) return <Loading />;
    return (
      <CreateYourLists
        students={students}
        classroomsCount={classroomsCount}
        gradeLevelNextYear={gradeLevelNextYear}
        studentIdsByRoom={studentIdsByRoom}
        fetchProfile={studentId => fetchProfile(workspaceId, studentId)}
        isEditable={isEditable}
        onClassListsChanged={onClassListsChanged}/>
    );
  }

  renderReviewAndShareNotes() {
    const {isEditable, onPrincipalNoteChanged, principalNoteText} = this.props;
    return (
      <div style={styles.stepContent}>
        <div>What else should your principal know?</div>
        <div style={{paddingTop: 5, paddingLeft: 0, padding: 10, fontSize: 12}}>
          Putting in these notes will help your principal and other team members understand all the different factors that you considered besides what shows up in the graphs.  This is also crucial information for a principal to know in case they need to move any students around over the summer.
        </div>
        <textarea
          value={principalNoteText}
          disabled={!isEditable}
          onChange={event => onPrincipalNoteChanged(event.target.value)}
          rows={12} 
          style={styles.textarea} />
      </div>
    );
  }

  renderShareWithPrincipal() {
    return (
      <div style={styles.stepContent}>
        <div>Ready to submit?</div>
      </div>
    );
  }
}
ClassListCreatorWorkflow.propTypes = {
  // server data
  schools: React.PropTypes.array,
  gradeLevelsNextYear: React.PropTypes.array,
  students: React.PropTypes.array,
  educators: React.PropTypes.array,

  // config
  steps: React.PropTypes.arrayOf(React.PropTypes.string).isRequired,
  availableSteps: React.PropTypes.arrayOf(React.PropTypes.number).isRequired,
  isEditable: React.PropTypes.bool.isRequired,

  // state
  stepIndex: React.PropTypes.number.isRequired,
  workspaceId: React.PropTypes.string.isRequired,
  schoolId: React.PropTypes.number,
  gradeLevelNextYear: React.PropTypes.string,
  authors: React.PropTypes.array.isRequired,
  classroomsCount: React.PropTypes.number.isRequired,
  planText: React.PropTypes.string.isRequired,
  studentIdsByRoom: React.PropTypes.object,
  principalNoteText: React.PropTypes.string.isRequired,

  // callbacks
  onStepChanged: React.PropTypes.func.isRequired,
  onSchoolIdChanged: React.PropTypes.func.isRequired,
  onGradeLevelNextYearChanged: React.PropTypes.func.isRequired,
  onEducatorsChanged: React.PropTypes.func.isRequired,
  onClassroomsCountIncremented: React.PropTypes.func.isRequired,
  onPlanTextChanged: React.PropTypes.func.isRequired,
  onClassListsChanged: React.PropTypes.func.isRequired,
  onPrincipalNoteChanged: React.PropTypes.func.isRequired
};

const styles = {
  root: {
    fontSize: 14,
    width: '100%'
  },
  heading: {
    marginTop: 20
  },
  button: {
    display: 'inline-block',
    margin: 5,
    cursor: 'pointer'
  },
  incrementButton: {
    display: 'inline-block',
    padding: 1,
    paddingLeft: 10,
    paddingRight: 10,
    fontSize: 16
  },
  stepContent: {
    margin: 20
  },
  videoLink: {
    display: 'inline-block',
    marginLeft: 5,
  },
  horizontalStepper: {
    paddingTop: 15
  },
  horizontalStepperContent: {
    borderTop: '1px solid #ccc',
    marginTop: 10
  },
  textarea: {
    border: '1px solid #ccc',
    width: '100%'
  }
};

