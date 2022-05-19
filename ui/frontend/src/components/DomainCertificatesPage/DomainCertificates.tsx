import React from 'react';
import { Buffer } from 'buffer';
import {
  ExpandableSection,
  FileUpload,
  Split,
  SplitItem,
  FormGroup,
  Panel,
  PanelMain,
  PanelMainBody,
  Stack,
  StackItem,
  Title,
} from '@patternfly/react-core';
import {
  CheckCircleIcon,
  ExclamationTriangleIcon,
  ExclamationCircleIcon,
} from '@patternfly/react-icons';
import {
  global_success_color_100 as successColor,
  global_warning_color_100 as warningColor,
  global_danger_color_100 as dangerColor,
} from '@patternfly/react-tokens';
import {
  getApiDomain,
  getConsoleDomain,
  getOauthDomain,
  getZtpfwDomain,
  TlsCertificate,
} from '../../copy-backend-common';
import { useK8SStateContext } from '../K8SStateContext';

import './DomainCertificates.css';

type CertificateProps = {
  name: string;
  domain: string;
};

const getTitle = (
  domainCert: TlsCertificate,
  name: string,
  domain: string,
): React.ReactElement | string => {
  let title: React.ReactElement | string;
  if (domainCert?.['tls.crt'] && domainCert?.['tls.key']) {
    title = (
      <>
        <CheckCircleIcon color={successColor.value} /> {name}: done for {domain}
      </>
    );
  } else if (!domainCert?.['tls.crt'] && !domainCert?.['tls.key']) {
    title = (
      <>
        <ExclamationTriangleIcon color={warningColor.value} /> {name}: generate self-signed for{' '}
        {domain}
      </>
    );
  } else {
    title = (
      <>
        <ExclamationCircleIcon color={dangerColor.value} /> {name}: missing for {domain}
      </>
    );
  }

  return title;
};

const Certificate: React.FC<CertificateProps> = ({ name, domain }) => {
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
      newCert[key] = Buffer.from(fr.result as string).toString('base64');
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

  return (
    <ExpandableSection
      toggleText={
        getTitle(
          domainCert,
          name,
          domain,
        ) as unknown as string /* TODO: Add support to Patternfly to avoid this ugly re-typying hack. It worsk so far. */
      }
      onToggle={() => setExpanded(!isExpanded)}
      isExpanded={isExpanded}
      displaySize="large"
    >
      <Split hasGutter>
        <SplitItem className="domain-certificate-item">
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
        </SplitItem>
        <SplitItem isFilled>
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
        </SplitItem>
      </Split>
    </ExpandableSection>
  );
};

export const DomainCertificates: React.FC = () => {
  const { domain } = useK8SStateContext();

  return (
    <>
      <Stack className="wizard-content" hasGutter>
        <StackItem>
          <Title headingLevel="h1" className="domain-certificate__h1">
            Upload your certificates
          </Title>
        </StackItem>
        <StackItem className="wizard-sublabel">
          Secure your domains with SSL/TLS certificates. If a certificate is not provided, a
          self-signed one will be automatically generated.
        </StackItem>
        <StackItem>
          <Panel isScrollable className="domain-certificates">
            <PanelMain tabIndex={0}>
              <PanelMainBody>
                <Certificate name="API" domain={getApiDomain(domain)} />
                <Certificate name="OAuth" domain={getOauthDomain(domain)} />
                <Certificate name="Setup" domain={getZtpfwDomain(domain)} />
                <Certificate name="Console" domain={getConsoleDomain(domain)} />
              </PanelMainBody>
            </PanelMain>
          </Panel>
        </StackItem>
      </Stack>
    </>
  );
};
