const textMap =  {
  300: 'SST Meeting',
  301: 'MTSS Meeting',
  302: 'Parent conversation',
  304: 'Something else',
  305: '9th Grade Experience',
  306: '10th Grade Experience',
  307: 'NEST',
  308: 'Counselor Meeting',
  400: 'BBST Meeting',
  500: 'STAT Meeting',
  501: 'CAT Meeting',
  502: '504 Meeting',
  503: 'SPED Meeting'
};
export function eventNoteTypeText(eventNoteTypeId) {
  return textMap[eventNoteTypeId] || 'Other';
}

const miniTextMap = {
  300: 'SST',
  301: 'MTSS',
  302: 'Parent',
  304: 'Other',
  305: 'NGE',
  306: '10GE',
  307: 'NEST',
  308: 'Counselor',
  400: 'BBST',
  500: 'STAT',
  501: 'CAT',
  502: '504',
  503: 'SPED'
};
export function eventNoteTypeTextMini(eventNoteTypeId) {
  return miniTextMap[eventNoteTypeId] || 'Other';
}

const GREEN = '#31AB39';
const YELLOW = '#CDD71A';
const RED = '#EB4B26';
const BLUE = '#139DEA';
const colorMap =  {
  300: GREEN,
  301: RED,
  302: YELLOW,
  305: BLUE,
  306: BLUE,
  307: BLUE,
  308: GREEN,
  400: GREEN,
  500: GREEN,
  501: BLUE,
  502: GREEN,
  503: GREEN
};
export function eventNoteTypeColor(eventNoteTypeId) {
  return colorMap[eventNoteTypeId] || '#666';
}