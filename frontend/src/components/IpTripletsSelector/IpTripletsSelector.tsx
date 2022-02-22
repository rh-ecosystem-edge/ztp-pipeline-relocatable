import React from 'react';
import { ExclamationCircleIcon } from '@patternfly/react-icons';
import { global_danger_color_100 as dangerColor } from '@patternfly/react-tokens';

import { IpTripletIndex, IpTripletProps } from '../types';
import { IpTripletSelectorValidationType } from '../types';
import { IpTriplet } from '../IpTriplet';

import './IpTripletsSelector.css';

export const IpTripletsSelector: React.FC<{
  address: string;
  setAddress: IpTripletProps['setAddress'];
  validation: IpTripletSelectorValidationType;
}> = ({ address, setAddress, validation }) => {
  const [focus, setFocus] = React.useState<IpTripletIndex | null>(0);
  const validated = validation.triplets || [];

  return (
    <>
      {([0, 1, 2, 3] as IpTripletIndex[]).map((position) => (
        <React.Fragment key={position}>
          {position > 0 ? '.' : ''}
          <IpTriplet
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
