import React from 'react';
import PropTypes from 'prop-types';
import _ from 'lodash';
import SimpleFilterSelect, {ALL} from './SimpleFilterSelect';


// For selecting a homeroom by teacher name
export default function SelectHomeroomByEducator({homeroomId, onChange, homerooms, style = undefined}) {
  const homeroomOptions = [{value: ALL, label: 'All'}].concat(_.compact(homerooms).map(homeroom => {
    return { value: homeroom.id.toString(), label: homeroom.educator.full_name };
  }));
  return (
    <SimpleFilterSelect
      style={style}
      placeholder="Homeroom..."
      value={homeroomId.toString()}
      onChange={onChange}
      options={homeroomOptions} />
  );
}
SelectHomeroomByEducator.propTypes = {
  homeroomId: PropTypes.any.isRequired, // could be 'all'
  onChange: PropTypes.func.isRequired,
  homerooms: PropTypes.arrayOf(PropTypes.shape({
    id: PropTypes.number.isRequired,
    name: PropTypes.string.isRequired,
    educator: PropTypes.shape({
      full_name: PropTypes.string, // or null
      email: PropTypes.string.isRequired
    })
  })).isRequired,
  style: PropTypes.object
};