import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { IpSelector, IpSelectorValidationType } from '../IpSelector';
import { ipAddressValidator } from '../utils';

export const VirtualIpSelector: React.FC = () => {
  const [ip, setIp] = React.useState('            ');
  const [validation, setValidation] = React.useState<IpSelectorValidationType>({
    valid: true,
    digits: [],
  });

  const handleSetIp = React.useCallback(
    (newIp: string) => {
      setValidation(ipAddressValidator(newIp, false));
      setIp(newIp);
    },
    [setIp],
  );

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">Virtual IP</Title>
      </StackItem>
      <StackItem>What is your virtual IP address?</StackItem>
      <StackItem>
        <IpSelector address={ip} setAddress={handleSetIp} validation={validation} />
      </StackItem>
      <StackItem isFilled>
        {!validation.valid && (
          <div className="address-validation-failed">Provided IP address is incorrect.</div>
        )}
      </StackItem>
    </Stack>
  );
};
