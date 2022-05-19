export type TlsCertificate = {
  'tls.crt': string;
  'tls.key': string;

  'tls.crt.filename'?: string;
  'tls.key.filename'?: string;
};

export type ChangeDomainInputType = {
  clusterDomain?: string;
  customCerts?: {
    [key: /* ~ domain */ string]: TlsCertificate;
  };
};
