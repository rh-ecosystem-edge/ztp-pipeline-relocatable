import React from 'react';
import { Button, ButtonVariant, PageHeaderTools } from '@patternfly/react-core';

export const HeaderTools: React.FC = () => (
  <PageHeaderTools>
    <Button component="a" href="/logout" variant={ButtonVariant.tertiary}>
      Log out
    </Button>
  </PageHeaderTools>
);
