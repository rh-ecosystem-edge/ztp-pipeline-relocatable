import React from 'react';
import { Nav, NavGroup, NavItem } from '@patternfly/react-core';
import { useLocation } from 'react-router-dom';

import {
  URI_API,
  URI_CONSOLE,
  URI_CREDENTIALS,
  URI_DOMAIN,
  URI_INGRESS,
  URI_LAYER3,
  URI_SSHKEY,
} from './routes';

import './Navigation.css';

export const Navigation: React.FC = () => {
  const location = useLocation();
  const activeItem = location.pathname;

  const onSelect = (result: { itemId: number | string; to: string }) => {
    // window.location.pathname = result.itemId as string; // Use this if we ever need to keep URL params
    window.location.href = result.to; // forget params
  };

  return (
    <Nav aria-label="Main navigation" theme="light" onSelect={onSelect} className="main-navigation">
      <NavGroup title="Networking">
        {/* Temporarily disabled
         <NavItem
          preventDefault
          to={URI_LAYER3}
          itemId="layer3"
          isActive={activeItem === URI_LAYER3}
        >
          TCP/IP
        </NavItem> */}
        <NavItem
          preventDefault
          to={URI_INGRESS}
          itemId="ingress"
          isActive={activeItem === URI_INGRESS}
        >
          Ingress
        </NavItem>
        <NavItem preventDefault to={URI_API} itemId="apiip" isActive={activeItem === URI_API}>
          API
        </NavItem>
        <NavItem
          preventDefault
          to={URI_DOMAIN}
          itemId="domain"
          isActive={activeItem === URI_DOMAIN}
        >
          Domain
        </NavItem>
      </NavGroup>

      <NavGroup title="User access">
        <NavItem
          preventDefault
          to={URI_CREDENTIALS}
          itemId="credentials"
          isActive={activeItem === URI_CREDENTIALS}
        >
          Username & password
        </NavItem>
        <NavItem
          preventDefault
          to={URI_SSHKEY}
          itemId="sshkey"
          isActive={activeItem === URI_SSHKEY}
        >
          SSH key
        </NavItem>
      </NavGroup>

      <NavGroup title="Console">
        <NavItem
          preventDefault
          to={URI_CONSOLE}
          itemId="console"
          isActive={activeItem === URI_CONSOLE}
        >
          OpenShift console
        </NavItem>
      </NavGroup>
    </Nav>
  );
};
