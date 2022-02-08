import React from 'react';

import { IpDigit, IpDigitIndex } from '../SingleIpDigit';

export const IpSelector: React.FC<{
  address: string;
  setAddress: (newAddress: string) => void;
}> = ({ address, setAddress }) => {
  const [focus, setFocus] = React.useState<IpDigitIndex>(0);

  return (
    <>
      <IpDigit
        position={0}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      <IpDigit
        position={1}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      <IpDigit
        position={2}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      .
      <IpDigit
        position={3}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      <IpDigit
        position={4}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      <IpDigit
        position={5}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      .
      <IpDigit
        position={6}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      <IpDigit
        position={7}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      <IpDigit
        position={8}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      .
      <IpDigit
        position={9}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      <IpDigit
        position={10}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
      <IpDigit
        position={11}
        address={address}
        setAddress={setAddress}
        focus={focus}
        setFocus={setFocus}
      />
    </>
  );
};
