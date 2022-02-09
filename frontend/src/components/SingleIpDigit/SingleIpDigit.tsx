import React from 'react';
import { TextInput } from '@patternfly/react-core';

import { IpDigitIndex, SingleIpDigitProps } from './types';

import './SingleIpDigit.css';

export const SingleIpDigit: React.FC<SingleIpDigitProps> = ({
  position,
  focus,
  address,
  setAddress,
  setFocus,
  validated,
}) => {
  const input = React.createRef<HTMLInputElement>();

  const onChange = React.useCallback(
    (v) => {
      const val = (v || '').trim();
      if (!val) {
        const newAddress = address.substring(0, position) + ' ' + address.substring(position + 1);
        setAddress(newAddress);
        setFocus(position as IpDigitIndex);
      }

      if (val.length === 1) {
        const num = parseInt(val);
        if (num >= 0 && num <= 9) {
          const newMask = address.substring(0, position) + num + address.substring(position + 1);

          setAddress(newMask);
          if (position < 11) {
            setFocus((position + 1) as IpDigitIndex);
          }
        }
      }
    },
    [position, address, setAddress, setFocus],
  );

  React.useEffect(() => {
    if (position === focus) {
      input?.current?.focus();
      input?.current?.select();
    }
  }, [focus, position, input]);

  let clzName = 'single-ip-digit';
  if (validated === 'success') {
    clzName += ' single-ip-digit-success';
  } else if (validated === 'error') {
    clzName += ' single-ip-digit-error';
  }

  return (
    <TextInput
      ref={input}
      className={clzName}
      value={address[position]}
      type="text"
      // validated={validated} Do not use this, we need simplified functionality here ...
      onChange={onChange}
      aria-label={`IP digit, position ${position + 1}`}
    />
  );
};
