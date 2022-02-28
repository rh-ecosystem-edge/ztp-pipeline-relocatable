import React from 'react';
import { useLocation } from 'react-router-dom';

const Redirect: React.FC<{ to: string; preservePathName?: boolean }> = ({
  to,
  preservePathName,
}) => {
  const location = useLocation();

  let url = to;
  if (preservePathName) {
    url += location.pathname;
    if (location.search) {
      url += location.search;
    }
  }

  console.info('Redirecting to: ', url);
  window.location.href = url;
  return <div />;
};
export default Redirect;
