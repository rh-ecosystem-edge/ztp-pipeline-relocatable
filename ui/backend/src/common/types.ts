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

export type HostInterfaceType = {
  name: string; // i.e. "eth0"
  // type: 'ethernet' | 'bond' | 'linux-bridge';
  // state: 'up' | 'down';
  ipv4: {
    // dhcp: boolean; always "false" for our static ips case
    // enabled: boolean; always true otherwise not found
    address?: {
      // We support only one static IP per interface
      ip?: string; // regular (dotted) IP form
      prefixLength?: number;
      validation?: string;

      gateway?: string;
      gatewayValidation?: string; // undefined if valid
    };
  };
};

export type HostType = {
  nodeName: string; // metadata.name of the Node resource
  hostname?: string; // kubernetes.io/hostname label in Node or nmstate spec.nodeSelector (optional)
  nncpName?: string; // metadata.name of the NodeNetworkConfigurationPolicy (if exists)

  role?: 'control' | 'worker'; // node-role.kubernetes.io/worker , node-role.kubernetes.io/master

  interfaces: HostInterfaceType[];
  dns?: string[];

  dnsValidation?: string; // undefined if valid
};
/*
export type Network4Type = {
  prefixLength: number;
  dns?: string;
  gw?: string;
};
*/
export type ChangeStaticIpsInputType = {
  hosts?: HostType[];
};
