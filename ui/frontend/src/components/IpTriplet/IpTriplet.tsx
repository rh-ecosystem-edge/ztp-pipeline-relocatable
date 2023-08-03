import React from 'react';
import { TextInput } from '@patternfly/react-core';

import { IpTripletIndex, IpTripletProps } from '../types';

import './IpTriplet.css';

export const IpTriplet: React.FC<IpTripletProps> = ({
  id,
  position,
  focus,
  address,
  setAddress,
  setFocus,
  validated,
  isNarrow,
  isDisabled,
}) => {
  const input = React.createRef<HTMLInputElement>();

  const onChange = React.useCallback(
    (v) => {
      const val = (v || '').trim();
      if (!val) {
        const newAddress =
          address.substring(0, position * 3) + '   ' + address.substring((position + 1) * 3);
        setAddress(newAddress);
        setFocus(position as IpTripletIndex);
      }

      if (val.length <= 3) {
        const num = parseInt(val);
        if (num >= 0 && num <= 255) {
          const numStr: string = num < 10 ? `  ${num}` : num < 100 ? ` ${num}` : `${num}`;
          const newAddr =
            address.substring(0, position * 3) + numStr + address.substring((position + 1) * 3);
          setAddress(newAddr);
          if (position < 3 && val.length === 3) {
            setFocus((position + 1) as IpTripletIndex);
          }
        }
      }
    },
    [position, address, setAddress, setFocus],
  );

  React.useEffect(() => {
    if (position === focus) {
      input?.current?.focus();
      setFocus(null);
    }
  }, [focus, position, input, setFocus]);

  let clzName = 'ip-triplet';
  if (validated === 'success') {
    clzName += ' ip-triplet-success';
  } else if (validated === 'error') {
    clzName += ' ip-triplet-error';
  }

  if (isNarrow) {
    clzName += ' ip-triplet__narrow';
  } else {
    clzName += ' ip-triplet__wide';
  }

  const trimmedValue = address.substring(position * 3, (position + 1) * 3).trim() || '';

  return (
    <TextInput
      ref={input}
      data-testid={id}
      className={clzName}
      value={trimmedValue}
      type="text"
      onChange={onChange}
      aria-label={`IP triplet, position ${position + 1}`}
      isDisabled={isDisabled}
    />
  );
};
