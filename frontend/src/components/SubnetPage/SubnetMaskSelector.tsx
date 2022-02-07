import React from 'react';
import { Stack, StackItem, Title, TextInput } from '@patternfly/react-core';

import './SubnetMaskSelector.css';

type MaskNumberIndex = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11;
type MaskNumberProps = {
  position: MaskNumberIndex;
  focus: MaskNumberIndex;
  mask: string;
  setMask: (newMask: string) => void;
  setFocus: (newPosition: MaskNumberIndex) => void;
};

const MaskNumber: React.FC<MaskNumberProps> = ({ position, focus, mask, setMask, setFocus }) => {
  const input = React.createRef<HTMLInputElement>();

  const onChange = React.useCallback(
    (v) => {
      const val = (v || '').trim();
      if (!val) {
        const newMask = mask.substring(0, position) + ' ' + mask.substring(position + 1);
        setMask(newMask);
        setFocus(position as MaskNumberIndex);
      }

      if (val.length === 1) {
        const num = parseInt(val);
        if (num >= 0 && num <= 9) {
          const newMask = mask.substring(0, position) + num + mask.substring(position + 1);
          setMask(newMask);
          if (position < 11) {
            setFocus((position + 1) as MaskNumberIndex);
          }
        }
      }
    },
    [position, mask, setMask, setFocus],
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
      className="mask-number"
      value={mask[position]}
      type="text"
      onChange={onChange}
      aria-label={`Subnet mask number, position ${position + 1}`}
    />
  );
};

export const SubnetMaskSelector: React.FC = () => {
  const [mask, setMask] = React.useState('            ');
  const [focus, setFocus] = React.useState<MaskNumberIndex>(0);

  React.createRef();
  return (
    <Stack className="welcome-bottom" hasGutter>
      <StackItem>
        <Title headingLevel="h1">Subnet mask</Title>
      </StackItem>
      <StackItem>What is your subnet mask address?</StackItem>
      <StackItem isFilled>
        <MaskNumber position={0} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        <MaskNumber position={1} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        <MaskNumber position={2} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        .
        <MaskNumber position={3} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        <MaskNumber position={4} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        <MaskNumber position={5} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        .
        <MaskNumber position={6} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        <MaskNumber position={7} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        <MaskNumber position={8} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        .
        <MaskNumber position={9} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        <MaskNumber position={10} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
        <MaskNumber position={11} mask={mask} setMask={setMask} focus={focus} setFocus={setFocus} />
      </StackItem>
    </Stack>
  );
};
