export type PersistErrorType = {
  title: string;
  message: string;
} | null;

export type TlsCertificate = {
  'tls.crt': string;
  'tls.key': string;
};
