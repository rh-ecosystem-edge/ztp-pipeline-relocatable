import React from 'react';
import {
  ExpandableSection,
  FileUpload,
  FormGroup,
  Panel,
  PanelMain,
  PanelMainBody,
  FlexItem,
  Flex,
  FlexProps,
  DescriptionList,
  DescriptionListGroup,
  DescriptionListTerm,
  DescriptionListDescription,
  ClipboardCopy,
  FormGroupProps,
} from '@patternfly/react-core';
import {
  global_success_color_100 as successColor,
  global_warning_color_100 as warningColor,
  global_danger_color_100 as dangerColor,
} from '@patternfly/react-tokens';
import {
  CheckCircleIcon,
  ExclamationTriangleIcon,
  ExclamationCircleIcon,
} from '@patternfly/react-icons';

import {
  getApiDomain,
  getConsoleDomain,
  getOauthDomain,
  getZtpfwDomain,
  TlsCertificate,
} from '../../copy-backend-common';
import { useK8SStateContext } from '../K8SStateContext';
import { toBase64 } from '../utils';

const getTitle = (
  isExpanded: boolean,
  domainCert: TlsCertificate,
  name: string,
  domain: string,
  certValidated: FormGroupProps['validated'],
  keyValidated: FormGroupProps['validated'],
): React.ReactElement | string => {
  let title: React.ReactElement | string;
  const forDomain = isExpanded ? undefined : <> certificate for {domain}</>;

  if (!domainCert?.['tls.crt'] && !domainCert?.['tls.key']) {
    title = (
      <>
        <ExclamationTriangleIcon color={warningColor.value} /> {name}: generate self-signed{' '}
        {forDomain}
      </>
    );
  } else if (certValidated === 'error' || keyValidated === 'error') {
    title = (
      <>
        <ExclamationCircleIcon color={dangerColor.value} /> {name}: incorrect {forDomain}
      </>
    );
  } else if (domainCert?.['tls.crt'] && domainCert?.['tls.key']) {
    title = (
      <>
        <CheckCircleIcon color={successColor.value} /> {name}: uploaded {forDomain}
      </>
    );
  } else {
    title = (
      <>
        <ExclamationCircleIcon color={dangerColor.value} /> {name}: missing {forDomain}
      </>
    );
  }

  return title;
};

type CertificateProps = {
  name: string;
  domain: string;

  isSpaceItemsNone?: boolean;
};

const Certificate: React.FC<CertificateProps> = ({ name, domain, isSpaceItemsNone }) => {
  const [isExpanded, setExpanded] = React.useState(false);
  const { customCerts, setCustomCertificate, customCertsValidation } = useK8SStateContext();

  const {
    certValidated,
    certLabelHelperText,
    certLabelInvalid,

    keyValidated,
    keyLabelInvalid,
  } = customCertsValidation[domain] || {};

  const domainCert = customCerts?.[domain] || { 'tls.crt': '', 'tls.key': '' };

  const idCert = `file-upload-certificate-${name.replaceAll(' ', '')}`;
  const idKey = `file-upload-key-${name.replaceAll(' ', '')}`;

  const onChange = async (key: 'tls.crt' | 'tls.key', file: File) => {
    const newCert = { ...domainCert };
    newCert[`${key}.filename`] = file.name;

    const fr = new FileReader();
    fr.onload = () => {
      newCert[key] = toBase64(fr.result as string);
      setCustomCertificate(domain, newCert);
    };
    fr.readAsText(file);
  };

  const onClear = (key: 'tls.crt' | 'tls.key') => {
    const newCert = { ...domainCert };
    newCert[key] = '';
    newCert[`${key}.filename`] = '';
    setCustomCertificate(domain, newCert);
  };

  const spaceItems: FlexProps['spaceItems'] = isSpaceItemsNone
    ? { default: 'spaceItemsXs' }
    : undefined;

  return (
    <ExpandableSection
      toggleText={
        getTitle(
          isExpanded,
          domainCert,
          name,
          domain,
          certValidated,
          keyValidated,
        ) as unknown as string /* TODO: Add support to Patternfly to avoid this ugly re-typying hack. It worsk so far. */
      }
      onToggle={() => setExpanded(!isExpanded)}
      isExpanded={isExpanded}
      displaySize="large"
    >
      <DescriptionList>
        <DescriptionListGroup>
          <DescriptionListTerm>Domain</DescriptionListTerm>
          <DescriptionListDescription>
            <ClipboardCopy hoverTip="Copy" clickTip="Copied" variant="inline-compact">
              {domain}
            </ClipboardCopy>
          </DescriptionListDescription>
        </DescriptionListGroup>
      </DescriptionList>

      <Flex spaceItems={spaceItems}>
        <FlexItem>
          <FormGroup
            fieldId={idCert}
            label="Certificate"
            isRequired={true}
            validated={certValidated}
            helperTextInvalid={certLabelInvalid}
            helperText={certLabelHelperText}
          >
            <FileUpload
              id={idCert}
              value={domainCert?.['tls.crt']}
              filename={domainCert?.['tls.crt.filename']}
              filenamePlaceholder="Drag and drop a file or upload one"
              browseButtonText="Upload"
              onFileInputChange={(_: unknown, file: File) => onChange('tls.crt', file)}
              onClearClick={() => {
                onClear('tls.crt');
              }}
            />
          </FormGroup>
        </FlexItem>

        <FlexItem>
          <FormGroup
            fieldId={idKey}
            label="Private key"
            isRequired={true}
            validated={keyValidated}
            helperTextInvalid={keyLabelInvalid}
          >
            <FileUpload
              id={idKey}
              value={domainCert?.['tls.key']}
              filename={domainCert?.['tls.key.filename']}
              filenamePlaceholder="Drag and drop a file or upload one"
              browseButtonText="Upload"
              onFileInputChange={(_: unknown, file: File) => onChange('tls.key', file)}
              onClearClick={() => {
                onClear('tls.key');
              }}
            />
          </FormGroup>
        </FlexItem>
      </Flex>
    </ExpandableSection>
  );
};

export const DomainCertificatesPanel: React.FC<{
  isScrollable?: boolean;
  isSpaceItemsNone?: boolean;
}> = ({ isScrollable, isSpaceItemsNone }) => {
  const { domain } = useK8SStateContext();

  return (
    <Panel isScrollable={isScrollable} className="domain-certificates">
      <PanelMain tabIndex={0}>
        <PanelMainBody>
          <Certificate
            name="API"
            domain={getApiDomain(domain)}
            isSpaceItemsNone={isSpaceItemsNone}
          />
          <Certificate
            name="OAuth"
            domain={getOauthDomain(domain)}
            isSpaceItemsNone={isSpaceItemsNone}
          />
          <Certificate
            name="Setup"
            domain={getZtpfwDomain(domain)}
            isSpaceItemsNone={isSpaceItemsNone}
          />
          <Certificate
            name="Console"
            domain={getConsoleDomain(domain)}
            isSpaceItemsNone={isSpaceItemsNone}
          />
        </PanelMainBody>
      </PanelMain>
    </Panel>
  );
};
