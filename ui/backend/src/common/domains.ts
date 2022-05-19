export const ZTPFW_UI_ROUTE_PREFIX = 'edge-cluster-setup';

export const getApiDomain = (domain: string) => `api.${domain}`;
export const getIngressDomain = (domain: string) => `apps.${domain}`;

export const getConsoleDomain = (domain: string) =>
  `console-openshift-console.${getIngressDomain(domain)}`;
export const getOauthDomain = (domain: string) => `oauth-openshift.${getIngressDomain(domain)}`;
export const getZtpfwDomain = (domain: string) =>
  `${ZTPFW_UI_ROUTE_PREFIX}.${getIngressDomain(domain)}`;
