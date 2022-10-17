import React from 'react';

import { Page } from '../Page';
import { ContentTwoRows } from '../ContentTwoRows';

import { WelcomeTop } from './WelcomeTop';
import { WelcomeBottom } from './WelcomeBottom';
import { useK8SStateContext } from '../K8SStateContext';
import { initialDataLoad } from './initialDataLoad';

export const WelcomePage: React.FC = () => {
  const [nextPage, setNextPage] = React.useState<string>();
  const [error, setError] = React.useState<string>();
  const { handleSetApiaddr, handleSetIngressIp, handleSetDomain, setClean } = useK8SStateContext();

  // Load initial data, switch between Inital vs. Edit flow
  React.useEffect(
    () => {
      initialDataLoad({
        setNextPage,
        setError,
        handleSetApiaddr,
        handleSetIngressIp,
        handleSetDomain,
        setClean,
      });
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [
      /* just once */
    ],
  );

  return (
    <Page>
      <ContentTwoRows
        top={<WelcomeTop />}
        bottom={<WelcomeBottom error={error} nextPage={nextPage} />}
      />
    </Page>
  );
};
