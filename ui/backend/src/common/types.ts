export type TlsCertificate = {
  'tls.crt': string;
  'tls.key': string;
};

export type ChangeDomainInputType = {
  clusterDomain?: string;
  customCerts: {
    domain: string;
    certificate: TlsCertificate;
  }[];
};
