import React from 'react';

import { Page } from '../Page';
import { ContentTwoCols } from '../ContentTwoCols';
import { useK8SStateContext } from '../K8SStateContext';
import { initialDataLoad } from '../WelcomePage/initialDataLoad';

import { Spinner } from './Spinner';
import { SettingsPageLeft } from './SettingsPageLeft';
import { SettingsPageRight } from './SettingsPageRight';

export const SettingsContent: React.FC<{ error?: string; forceReload: () => void }> = ({
  error,
  forceReload,
}) => (
  <Page>
    <ContentTwoCols
      left={<SettingsPageLeft />}
      right={
        <SettingsPageRight isInitialEdit={false} initialError={error} forceReload={forceReload} />
      }
    />
  </Page>
);

export const SettingsLoading: React.FC = () => (
  <Page>
    <ContentTwoCols left={<SettingsPageLeft />} right={<Spinner />} />
  </Page>
);

export const Settings: React.FC = () => {
  const [error, setError] = React.useState<string>();
  const [isDataLoaded, setDataLoaded] = React.useState<boolean>(false);
  const [isReload, setReload] = React.useState(true);
  const { handleSetApiaddr, handleSetIngressIp, handleSetDomain, setClean } = useK8SStateContext();

  // Following is needed when navigated directly by setting the URL in the browser
  // It is not needed when navigated from the WelcomePage but let's refresh to show recent data anyway
  React.useEffect(() => {
    if (isReload) {
      setReload(false);
      initialDataLoad({
        setNextPage: () => setDataLoaded(true),
        setError,
        handleSetApiaddr,
        handleSetIngressIp,
        handleSetDomain,
        setClean,
      });
    }
  }, [handleSetApiaddr, handleSetIngressIp, handleSetDomain, isReload, setClean]);

  return isDataLoaded ? (
    <SettingsContent error={error} forceReload={() => setReload(true)} />
  ) : (
    <SettingsLoading />
  );
};
