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
import { toBase64 } from '../utils';
import { CertificateProps } from '../types';

import './DomainCertificates.css';

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
        <ExclamationTriangleIcon color={warningColor.value} /> {name}: generate self-signed
      </>
    );
  } else if (certValidated === 'error' || keyValidated === 'error') {
    title = (
      <>
        <ExclamationCircleIcon color={dangerColor.value} /> {name}: incorrect
      </>
    );
  } else if (domainCert?.['tls.crt'] && domainCert?.['tls.key']) {
    title = (
      <>
        <CheckCircleIcon color={successColor.value} /> {name}: uploaded
      </>
    );
  } else {
    title = (
      <>
        <ExclamationCircleIcon color={dangerColor.value} /> {name}: missing
      </>
    );
  }

  return title;
};

const Certificate: React.FC<CertificateProps> = ({
  name,
  domain,
  isSpaceItemsNone,
  customCerts,
  setCustomCertificate,
  customCertsValidation,
}) => {
  const [isExpanded, setExpanded] = React.useState(false);

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

  // const spaceItems: FlexProps['spaceItems'] = isSpaceItemsNone
  //   ? { default: 'spaceItemsXs' }
  //   : undefined;

  return (
    <ExpandableSection
      className="domain-certificate"
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
          <DescriptionListTerm>For domain</DescriptionListTerm>
          <DescriptionListDescription>
            <ClipboardCopy hoverTip="Copy" clickTip="Copied" variant="inline-compact">
              {domain}
            </ClipboardCopy>
          </DescriptionListDescription>
        </DescriptionListGroup>
      </DescriptionList>

      <Flex spaceItems={{ default: 'spaceItemsNone' }}>
        <FlexItem className="domain-certificate__keycert">
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

        <FlexItem className="domain-certificate__keycert">
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
  domain: string;
  isScrollable?: boolean;

  customCerts: CertificateProps['customCerts'];
  setCustomCertificate: CertificateProps['setCustomCertificate'];
  customCertsValidation: CertificateProps['customCertsValidation'];
  // isSpaceItemsNone?: boolean;
}> = ({ domain, isScrollable, ...sharedProps }) => {
  return (
    <Panel isScrollable={isScrollable} className="domain-certificates__panel">
      <PanelMain tabIndex={0}>
        <PanelMainBody>
          <Certificate name="API" domain={getApiDomain(domain)} {...sharedProps} />
          <Certificate name="OAuth" domain={getOauthDomain(domain)} {...sharedProps} />
          <Certificate name="Setup" domain={getZtpfwDomain(domain)} {...sharedProps} />
          <Certificate name="Console" domain={getConsoleDomain(domain)} {...sharedProps} />
        </PanelMainBody>
      </PanelMain>
    </Panel>
  );
};
