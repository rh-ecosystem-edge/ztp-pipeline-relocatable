import React from 'react';
import { TextInput } from '@patternfly/react-core';

import './SingleIpDigit.css';

export type IpDigitIndex = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11;

type SingleIpDigitProps = {
  position: IpDigitIndex;
  focus: IpDigitIndex;
  address: string;
  setAddress: (newAddress: string) => void;
  setFocus: (newPosition: IpDigitIndex) => void;
};

export const IpDigit: React.FC<SingleIpDigitProps> = ({
  position,
  focus,
  address,
  setAddress,
  setFocus,
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

  return (
    <TextInput
      ref={input}
      className="single-ip-digit"
      value={address[position]}
      type="text"
      onChange={onChange}
      aria-label={`IP digit, position ${position + 1}`}
    />
  );
};
