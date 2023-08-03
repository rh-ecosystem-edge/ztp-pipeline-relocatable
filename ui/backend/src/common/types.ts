export type TlsCertificate = {
  'tls.crt': string;
  'tls.key': string;

  'tls.crt.filename'?: string;
  'tls.key.filename'?: string;
};

export type CustomCertsType = {
  [key: /* ~ domain */ string]: TlsCertificate;
};

export type ChangeDomainInputType = {
  clusterDomain?: string;
  customCerts?: CustomCertsType;
};

export type ValidateDomainAPIResult = { result: boolean };
export type ValidateDomainAPIInput = { domain?: string };
