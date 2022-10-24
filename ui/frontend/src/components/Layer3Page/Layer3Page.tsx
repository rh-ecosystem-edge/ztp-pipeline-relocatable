import React from 'react';
import { FormGroup, Radio, Text, TextContent, TextVariants } from '@patternfly/react-core';

import { BasicLayout } from '../BasicLayout';
import { ContentSection } from '../ContentSection';
import { Page } from '../Page';
import { HostType } from '../../copy-backend-common';
import { ipAddressValidator, prefixLengthValidator } from '../utils';

import { HostStaticIP } from './HostStaticIP';

import './Layer3Page.css';
import { loadStaticIPs } from './dataLoad';
import { getAllNodes } from '../../resources/node';
import { getAllNodeNetworkStates } from '../../resources/nodeNetworkStates';

export const Layer3Page = () => {
  const [error, setError] = React.useState<UIError>();
  const [isAutomatic, setAutomatic] = React.useState(true);
  const [hosts, setHosts] = React.useState<HostType[]>([]);

  const handleSetHost = React.useCallback(
    (newHost: HostType) => {
      // List of DNS servers
      newHost.dnsValidation = undefined;
      newHost.dns?.some((dnsIp) => {
        const validation = ipAddressValidator(dnsIp);
        if (validation) {
          newHost.dnsValidation = validation;
          return true; // break
        }
        return false;
      });

      newHost.interfaces?.forEach((intf) => {
        // single GW
        if (intf.ipv4.address?.gateway) {
          intf.ipv4.address.gatewayValidation = ipAddressValidator(intf.ipv4.address.gateway);
        }

        // single static IP and subnet prefix
        if (intf.ipv4?.address) {
          const validation = ipAddressValidator(intf.ipv4?.address?.ip);
          intf.ipv4.address.validation = validation;

          if (!validation && intf.ipv4.address.prefixLength !== undefined) {
            // prefix-length
            intf.ipv4.address.validation = prefixLengthValidator(intf.ipv4.address.prefixLength);
          }
        }
      });

      // find host by nodeName or add new record
      const hostIndex = hosts.findIndex((h) => h.nodeName === newHost.nodeName);
      if (hostIndex >= 0) {
        hosts[hostIndex] = newHost;
      } else {
        hosts.push(newHost);
      }

      setHosts([...hosts]);
    },
    [hosts, setHosts],
  );

  React.useEffect(
    () => {
      const doItAsync = async () => {
        setHosts(await loadStaticIPs(setError));
      };

      doItAsync();
    },
    [
      /* One-time action */
    ],
  );

  const clearStaticIPs = () => {
    console.log('-- TODO: clearStaticIPs()');
  };

  return (
    <Page>
      <BasicLayout
        isValueChanged={false}
        isSaving={false}
        error={error}
        onSave={() => {
          console.log('TODO: onSave');
        }}
      >
        <ContentSection>
          <TextContent>
            <Text component={TextVariants.h1}>TCP/IP</Text>
            <Text className="text-sublabel">
              Choose whether or not you want to automatically assign IP addresses for your device.
            </Text>
          </TextContent>
          <br />
          <FormGroup
            fieldId="layer3switch__auto"
            label="IPv4 configuration"
            isRequired={true}
            className="layer3-page__staticip-switch"
          >
            <Radio
              data-testid="layer3switch__auto"
              id="layer3switch__auto"
              label="Automatic (DHCP)"
              name="automatic"
              isChecked={isAutomatic}
              onChange={() => {
                setAutomatic(true);
                clearStaticIPs();
              }}
            />
            <Radio
              data-testid="layer3switch__static"
              id="layer3switch__static"
              label="Manual (Static)"
              name="manual"
              isChecked={!isAutomatic}
              onChange={() => setAutomatic(false)}
            />
          </FormGroup>
        </ContentSection>

        {!isAutomatic && (
          <ContentSection>
            <TextContent>
              <Text className="text-sublabel">
                Configure your TCP/IP settings for all available hosts
              </Text>
              <Text className="text-sublabel-dense">
                All control plane nodes must be on a single subnet.
              </Text>
            </TextContent>
            <br />
            {hosts.map((h, idx) => {
              // Assumption: hosts are sorted by "role", control planes first
              const isLeadingControlPlane = idx === 0;

              return (
                <HostStaticIP
                  key={h.nodeName}
                  host={h}
                  handleSetHost={handleSetHost}
                  // isEdit={isEdit}
                  isLeadingControlPlane={isLeadingControlPlane}
                />
              );
            })}
          </ContentSection>
        )}
      </BasicLayout>
    </Page>
  );
};
