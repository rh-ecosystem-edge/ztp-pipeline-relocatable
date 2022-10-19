import React from 'react';
import { TextContent, TextVariants, Text, FormGroup, Spinner } from '@patternfly/react-core';

import { BasicLayout } from '../BasicLayout';
import { ContentSection } from '../ContentSection';
import { Page } from '../Page';
import { IpTripletProps, IpTripletSelectorValidationType, UIError } from '../types';
import { initialValidation, IpTripletsSelector } from '../IpTripletsSelector';
import { ipTripletAddressValidator } from '../utils';

import { loadIngressData } from './dataLoad';
import { saveIngress } from './persist';

export const IngressPage = () => {
  const [error, setError] = React.useState<UIError>();
  const [ingressVip, setIngressVip] = React.useState<string>();
  const [loadedValue, setLoadedValue] = React.useState<string>();
  const [isSaving, setIsSaving] = React.useState(false);
  const [validation, setValidation] =
    React.useState<IpTripletSelectorValidationType>(initialValidation);

  React.useEffect(
    () => {
      const doItAsync = async () => {
        // const loaded = '192168  1  1'; // Test data only

        const loaded = await loadIngressData({ setError });

        setIngressVip(loaded);
        setLoadedValue(loaded);
      };

      doItAsync();
    },
    [
      /* Just once */
    ],
  );

  const setAddress: IpTripletProps['setAddress'] = (newAddress) => {
    setIngressVip(newAddress);

    // TODO: Load API VIP as the "reservedIp"
    const reservedIp: string | undefined = undefined;

    setValidation(ipTripletAddressValidator(newAddress, reservedIp));
  };

  const onSave = async () => {
    if (!ingressVip) {
      return;
    }

    setIsSaving(true);

    if (!(await saveIngress(setError, ingressVip))) {
      console.error('Failed to persist Ingress IP.');
    }

    setIsSaving(false);
  };

  const isValueChanged = loadedValue !== ingressVip;

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
              Assign the IP address that’ll be used for new routes and traffic managed by the
              ingress controller.
            </Text>
          </TextContent>
          <br />
          {!ingressVip && <Spinner size="sm" />}
          {ingressVip && (
            <FormGroup
              fieldId="ingress-ip"
              label="IP address"
              isRequired={true}
              helperTextInvalid={validation.message}
              validated={validation.valid ? 'default' : 'error'}
            >
              <IpTripletsSelector
                id="ingress-ip"
                address={ingressVip}
                setAddress={setAddress}
                validation={validation}
                isDisabled={!ingressVip || isSaving}
              />
            </FormGroup>
          )}
        </ContentSection>
      </BasicLayout>
    </Page>
  );
};
