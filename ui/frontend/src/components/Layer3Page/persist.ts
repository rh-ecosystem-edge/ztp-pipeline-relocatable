import { ChangeStaticIpsInputType, HostInterfaceType, HostType } from '../../copy-backend-common';
import { postRequest } from '../../resources';
import { setUIErrorType } from '../types';

export const saveLayer3 = async (
  setError: setUIErrorType,
  isAutomatic: boolean,
  hosts: HostType[],
) => {
  let input: ChangeStaticIpsInputType;

  if (isAutomatic) {
    input = {
      hosts: hosts.map(
        // Reduce the data to valid ones only
        (h): HostType => ({
          hostname: h.hostname,
          nodeName: h.nodeName,
          nncpName: h.nncpName,

          // DNS is retrievd via DHCP
          // dns: h.dns,

          interfaces: h.interfaces.map(
            (i): HostInterfaceType => ({
              name: i.name,
              ipv4: {
                dhcp: true,
                enabled: true,
              },
            }),
          ),
        }),
      ),
    };
  } else {
    input = {
      hosts: hosts.map(
        // Reduce the data to valid ones only
        (h): HostType => ({
          hostname: h.hostname,
          nodeName: h.nodeName,
          nncpName: h.nncpName,

          dns: h.dns,

          interfaces: h.interfaces.map(
            (i): HostInterfaceType => ({
              name: i.name,
              ipv4: {
                dhcp: false,
                enabled: true,
                address: {
                  ip: i.ipv4.address?.ip,
                  prefixLength: i.ipv4.address?.prefixLength,
                  gateway: i.ipv4.address?.gateway,
                },
              },
            }),
          ),
        }),
      ),
    };
  }

  try {
    // Due to complexity, the flow has been moved to backend to decrease risks related to network communication
    await postRequest('/changeStaticIps', input).promise;
  } catch (e) {
    console.error(e);
    setError({
      title: 'Changing TCP/IP setting failed.',
      message: `Failed to change TCP/IP layer of the hosts.`,
    });
    return false;
  }
};
