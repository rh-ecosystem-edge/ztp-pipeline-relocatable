import React from 'react';
import { TextContent, TextVariants, Text, FormGroup, Spinner } from '@patternfly/react-core';

import { BasicLayout } from '../BasicLayout';
import { ContentSection } from '../ContentSection';
import { Page } from '../Page';
import { IpTripletProps, IpTripletSelectorValidationType, UIError } from '../types';
import { initialValidation, IpTripletsSelector } from '../IpTripletsSelector';
import { ipTripletAddressValidator } from '../utils';

import { loadApiData } from './dataLoad';
import { saveApi } from './persist';

export const APIPage = () => {
  const [error, setError] = React.useState<UIError>();
  const [apiVip, setApiVip] = React.useState<string>();
  const [loadedValue, setLoadedValue] = React.useState<string>();
  const [isSaving, setIsSaving] = React.useState(false);
  const [validation, setValidation] =
    React.useState<IpTripletSelectorValidationType>(initialValidation);

  React.useEffect(
    () => {
      const doItAsync = async () => {
        // const loaded = '192168  1  1'; // Test data only

        const loaded = await loadApiData({ setError });

        setApiVip(loaded);
        setLoadedValue(loaded);
      };

      doItAsync();
    },
    [
      /* Just once */
    ],
  );

  const setAddress: IpTripletProps['setAddress'] = (newAddress) => {
    setApiVip(newAddress);

    // TODO: Load Ingress VIP as the "reservedIp"
    const reservedIp: string | undefined = undefined;

    setValidation(ipTripletAddressValidator(newAddress, reservedIp));
  };

  const onSave = async () => {
    if (!apiVip) {
      return;
    }

    setIsSaving(true);

    if (!(await saveApi(setError, apiVip))) {
      console.error('Failed to persist API IP.');
    }

    setIsSaving(false);
  };

  const isValueChanged = loadedValue !== apiVip;

  return (
    <Page>
      <BasicLayout
        error={error}
        isValueChanged={isValueChanged}
        isSaving={isSaving}
        onSave={onSave}
      >
        <ContentSection>
          <TextContent>
            <Text component={TextVariants.h1}>Ingress</Text>
            <Text className="text-sublabel">
              Assign the IP address that’ll be used for accessing OpenShift API.
            </Text>
          </TextContent>
          <br />
          {!apiVip && <Spinner size="sm" />}
          {apiVip && (
            <FormGroup
              fieldId="api-ip"
              label="IP address"
              isRequired={true}
              helperTextInvalid={validation.message}
              validated={validation.valid ? 'default' : 'error'}
            >
              <IpTripletsSelector
                id="api-ip"
                address={apiVip}
                setAddress={setAddress}
                validation={validation}
                isDisabled={!apiVip || isSaving}
              />
            </FormGroup>
          )}
        </ContentSection>
      </BasicLayout>
    </Page>
  );
};
