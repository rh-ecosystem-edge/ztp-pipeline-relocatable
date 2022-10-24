import React from 'react';

import {
  ExpandableSection,
  Flex,
  FlexItem,
  Form,
  FormGroup,
  TextInput,
} from '@patternfly/react-core';
import { ExclamationCircleIcon } from '@patternfly/react-icons';
import { global_danger_color_100 as dangerColor } from '@patternfly/react-tokens';

import { getSubnetRange } from '../utils';
import { HostType } from '../../copy-backend-common';

import './HostStaticIP.css';

const getRole = (host: HostType) => {
  if (host.role === 'control') {
    return 'control plane';
  }
  return host.role || 'default role';
};

// https://docs.openshift.com/container-platform/4.7/networking/k8s_nmstate/k8s-nmstate-about-the-k8s-nmstate-operator.html
// TODO:
// - Force single network configuration for all masters
//   - Check if master's IP address is of the expected range
// - allow sharing of network configuration by workers (in the future, so far we have just one worker)
export const HostStaticIP: React.FC<{
  host: HostType;
  handleSetHost: (newHost: HostType) => void;
  isEdit?: boolean;
  isLeadingControlPlane: boolean;
}> = ({
  host,
  handleSetHost,
  isEdit = true /* TODO: do we need this?? */,
  isLeadingControlPlane,
}) => {
  const [isExpanded, setExpanded] = React.useState(false);

  const interfaces = host.interfaces;
  const toggleText = `${getRole(host)}: ${host.hostname || 'Host'}`;

  const dns = host.dns || [];
  const dnsValidation = host.dnsValidation;

  const canEditSubnet = host.role !== 'control' || isLeadingControlPlane;

  return (
    <ExpandableSection
      toggleText={toggleText}
      onToggle={() => setExpanded(!isExpanded)}
      isExpanded={isExpanded}
      displaySize="large"
    >
      <Form>
        <Flex>
          {interfaces.map((intf) => {
            // TODO: eventually extend for multiple addresses per a single intreface
            const helperText =
              (!intf.ipv4.address?.validation &&
                getSubnetRange(intf.ipv4.address?.ip, intf.ipv4.address?.prefixLength)) ||
              'IP address of the interface.';

            const idIP = `host-static-ip-${host.hostname}`;
            const idPrefixLength = `${idIP}-prefix-length`;
            const idGateway = `${idIP}-gw`;
            const idDns = `${idIP}-dns`;

            const address = intf.ipv4?.address?.ip; // || TWELVE_SPACES;
            const prefixLength = intf.ipv4.address?.prefixLength || '';
            const gateway = intf.ipv4.address?.gateway || '';
            const gatewayValidation = intf.ipv4.address?.gatewayValidation;

            const setAddress = (addr: string) => {
              // So far we support only one IP per interface
              intf.ipv4.address = intf.ipv4.address || {};
              intf.ipv4.address.ip = addr;
              handleSetHost(host);
            };

            const setPrefixLength = (val: string) => {
              const prefixLength = parseInt(val);
              if (!isNaN(prefixLength) && prefixLength > 0 && prefixLength < 32) {
                intf.ipv4.address = intf.ipv4.address || {};
                intf.ipv4.address.prefixLength = prefixLength;
                handleSetHost(host);
              }
            };

            const setGateway = (val: string) => {
              intf.ipv4.address = intf.ipv4.address || {};
              intf.ipv4.address.gateway = val;
              handleSetHost(host);
            };

            const setDns = (val: string) => {
              const nameservers = val.split(',').map((ns: string) => ns.trim());
              host.dns = nameservers;
              handleSetHost(host);
            };

            return (
              <React.Fragment key={intf.name}>
                <FlexItem>
                  <FormGroup
                    fieldId={idIP}
                    label={`${intf.name}: Static IP / network prefix`}
                    isRequired={true}
                    validated={intf.ipv4.address?.validation ? 'error' : 'default'}
                    helperTextInvalid={intf.ipv4.address?.validation}
                    helperText={helperText}
                  >
                    <TextInput
                      id={idIP}
                      data-testid={idIP}
                      value={address}
                      isDisabled={!isEdit}
                      onChange={setAddress}
                      // type="number"
                      className="host-static-ip__input"
                    />
                    /
                    <TextInput
                      id={idPrefixLength}
                      data-testid={idPrefixLength}
                      value={prefixLength}
                      isDisabled={!isEdit || !canEditSubnet}
                      onChange={setPrefixLength}
                      // type="number"
                      className="host-static-ip-prefix-length"
                    />
                    {intf.ipv4.address?.validation && (
                      <ExclamationCircleIcon
                        color={dangerColor.value}
                        className="validation-icon"
                      />
                    )}
                  </FormGroup>
                </FlexItem>
                <FlexItem>
                  <FormGroup
                    fieldId={idGateway}
                    label="Gateway"
                    isRequired={true}
                    validated={gatewayValidation ? 'error' : 'default'}
                    helperTextInvalid={gatewayValidation}
                    helperText="IP from the subnet to forward trafic to"
                  >
                    <TextInput
                      id={idGateway}
                      data-testid={idGateway}
                      value={gateway}
                      isDisabled={!isEdit || !canEditSubnet}
                      onChange={setGateway}
                    />
                  </FormGroup>
                </FlexItem>
                <FlexItem>
                  <FormGroup
                    fieldId={idDns}
                    label="Nameserver"
                    isRequired={true}
                    validated={dnsValidation ? 'error' : 'default'}
                    helperTextInvalid={dnsValidation}
                    helperText="A comma-separated list"
                    className="host-static-ip-nameserver"
                  >
                    <TextInput
                      id={idDns}
                      data-testid={idDns}
                      value={dns.join(',')}
                      isDisabled={!isEdit || !canEditSubnet}
                      onChange={setDns}
                    />
                  </FormGroup>
                </FlexItem>
              </React.Fragment>
            );
          })}
        </Flex>
      </Form>
    </ExpandableSection>
  );
};
