import moment from 'moment';
import DashboardHelpers from './DashboardHelpers';
import {createStudents} from './DashboardTestData';



describe('GroupByHomeroom', () => {
  it('returns a hash with homerooms as keys', () => {
    const students = createStudents(moment.utc());
    const groupedStudents = DashboardHelpers.groupByHomeroom(students);
    expect(groupedStudents).toEqual({
      'Test 1': [students[0], students[1], students[2]],
      'Test 2': [students[3], students[4]],
      'No Homeroom': [students[5]]
    });
  });
});

describe('absenceEvents', () => {
  it('returns an array of student absences', () =>{
    const students = createStudents(moment.utc());
    const events = DashboardHelpers.absenceEvents(students);
    expect(events.length).toEqual(12);
  });
});

describe('filterExcusedEvents', () => {
  const students = createStudents(moment.utc());
  const events = DashboardHelpers.absenceEvents(students);
  const filteredEvents = DashboardHelpers.filterExcusedEvents(events);
  expect(events.length).toEqual(10);
});

describe('tardyEventsByDay', () => {
  it('returns a hash with distinct days as keys', () =>{
    const students = createStudents(moment.utc());
    const events = DashboardHelpers.tardyEventsByDay(students);
    expect(Object.keys(events).length).toEqual(5);
  });
});

describe('averageDailyAttendance', () => {
  it('returns the average number of events for each day', () => {
    const nowMoment = moment.utc();
    const students = createStudents(nowMoment);
    const events = DashboardHelpers.absenceEventsByDay(students);
    const averageDailyAttendance = DashboardHelpers.averageDailyAttendance(events, students.length);
    const result = Object.keys(averageDailyAttendance).map(x => averageDailyAttendance[x]);
    expect(result.sort()).toEqual([16.7,33.3,66.7,83.3]);
  });
});

describe('filterDates', () => {
  it('removes dates outside the date range', () => {
    const nowMoment = moment.utc();
    const students = createStudents(nowMoment);
    const events = DashboardHelpers.absenceEventsByDay(students);
    const averageDailyAttendance = DashboardHelpers.averageDailyAttendance(events, students.length);
    const range = Object.keys(averageDailyAttendance);
    const result = DashboardHelpers.filterDates(range, moment.utc().subtract(4, 'months'), moment.utc());
    expect(result.length).toEqual(3);
  });
});
