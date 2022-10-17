import React from 'react';
import { ExclamationCircleIcon } from '@patternfly/react-icons';
import { global_danger_color_100 as dangerColor } from '@patternfly/react-tokens';
import { TextInput } from '@patternfly/react-core';

import { IpTripletIndex, IpTripletProps, IpTripletSelectorValidationType } from '../types';
import { IpTriplet } from '../IpTriplet';
import { addIpDots } from '../utils';

export const initialValidation: IpTripletSelectorValidationType = {
  valid: true,
  triplets: ['default', 'default', 'default', 'default'],
  message: undefined,
};

export const IpTripletsSelector: React.FC<{
  id?: string;
  address: string;
  setAddress: IpTripletProps['setAddress'];
  validation: IpTripletSelectorValidationType;
  isNarrow?: boolean;
  isDisabled?: boolean;
}> = ({ id = 'ip-triplet', address, setAddress, validation, isNarrow, isDisabled }) => {
  const [focus, setFocus] = React.useState<IpTripletIndex | null>(0);
  const validated = validation.triplets || [];

  //   if (isDisabled) {
  //     return <TextInput id={id} data-testid={id} value={addIpDots(address)} isDisabled={true} />;
  //   }

  return (
    <div id={id}>
      {([0, 1, 2, 3] as IpTripletIndex[]).map((position) => (
        <React.Fragment key={position}>
          {position > 0 ? '.' : ''}
          <IpTriplet
            key={position}
            id={`${id}-${position}`}
            position={position}
            address={address}
            setAddress={setAddress}
            focus={focus}
            setFocus={setFocus}
            validated={validated[position]}
            isNarrow={isNarrow}
            isDisabled={isDisabled}
          />
        </React.Fragment>
      ))}
      {!validation.valid && (
        <ExclamationCircleIcon color={dangerColor.value} className="validation-icon" />
      )}
    </div>
  );
};
