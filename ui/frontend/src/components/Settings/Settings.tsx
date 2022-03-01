import React from 'react';

import { Page } from '../Page';
import { ContentTwoCols } from '../ContentTwoCols';

import { SettingsPageLeft } from './SettingsPageLeft';
import { SettingsPageRight } from './SettingsPageRight';
import { useK8SStateContext } from '../K8SStateContext';
import { initialDataLoad } from '../WelcomePage/initialDataLoad';

export const Settings: React.FC = () => {
  const [error, setError] = React.useState<string>();
  const [isDataLoaded, setDataLoaded] = React.useState<boolean>(false);
  const { handleSetApiaddr, handleSetIngressIp /* TODO: domain */ } = useK8SStateContext();

  // Following is needed when navigated directly by setting the URL in the browser
  // It is not needed when navigated from the WelcomePage but let's refresh to show recent data anyway
  React.useEffect(
    () => {
      initialDataLoad({
        setNextPage: () => setDataLoaded(true),
        setError,
        handleSetApiaddr,
        handleSetIngressIp,
      });
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [
      /* just once */
    ],
  );

  return isDataLoaded ? (
    <Page>
      <ContentTwoCols
        left={<SettingsPageLeft />}
        right={<SettingsPageRight isInitialEdit={false} initialError={error} />}
      />
    </Page>
  ) : (
    <div>TODO: Loading spinner</div>
  );
};
