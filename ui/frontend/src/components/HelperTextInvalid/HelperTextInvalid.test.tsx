import React from 'react';
import { render } from '@testing-library/react';
import { HelperTextInvalid } from './HelperTextInvalid';

describe('HelperTextInvalid', () => {
  it('can render empty', () => {
    const { container } = render(<HelperTextInvalid />);
    expect(container).toMatchSnapshot();
  });

  it('can render with text', () => {
    const { container } = render(<HelperTextInvalid validation="My validation text" />);
    expect(container).toMatchSnapshot();
  });
});
