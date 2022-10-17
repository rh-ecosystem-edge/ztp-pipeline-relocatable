import React from 'react';
import { BasicLayout } from '../BasicLayout';
import { ContentSection } from '../ContentSection';
import { Page } from '../Page';

export const IngressPage = () => {
  return (
    <Page>
      <BasicLayout>
        <ContentSection>Ingress page content</ContentSection>
      </BasicLayout>
    </Page>
  );
};
