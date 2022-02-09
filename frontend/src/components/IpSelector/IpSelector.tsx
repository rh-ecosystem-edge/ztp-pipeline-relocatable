import React from 'react';
import { ExclamationCircleIcon } from '@patternfly/react-icons';
import { global_danger_color_100 as dangerColor } from '@patternfly/react-tokens';

import { SingleIpDigit, IpDigitIndex, SingleIpDigitProps } from '../SingleIpDigit';
import { IpSelectorValidationType } from './types';

import './IpSelector.css';

export const IpSelector: React.FC<{
  address: string;
  setAddress: SingleIpDigitProps['setAddress'];
  validation: IpSelectorValidationType;
}> = ({ address, setAddress, validation }) => {
  const [focus, setFocus] = React.useState<IpDigitIndex>(0);
  const validated = validation.digits || [];

  return (
    <>
      {([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11] as IpDigitIndex[]).map((position) => (
        <React.Fragment key={position}>
          {position > 0 && position % 3 === 0 && <>.</>}
          <SingleIpDigit
            key={position}
            position={position}
            address={address}
            setAddress={setAddress}
            focus={focus}
            setFocus={setFocus}
            validated={validated[position]}
          />
        </React.Fragment>
      ))}
      {!validation.valid && (
        <ExclamationCircleIcon color={dangerColor.value} className="validation-icon" />
      )}
    </>
  );
};
