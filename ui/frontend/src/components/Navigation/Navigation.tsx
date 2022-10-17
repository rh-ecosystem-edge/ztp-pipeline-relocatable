import React from 'react';
import { Nav, NavGroup, NavItem } from '@patternfly/react-core';
import { useLocation } from 'react-router-dom';

import './Navigation.css';

export const Navigation: React.FC = () => {
  const location = useLocation();
  const activeItem = location.pathname;

  const onSelect = (result: { itemId: number | string }) => {
    // window.location.pathname = result.itemId as string; // Use this if we ever need to keep URL params
    window.location.href = result.itemId as string; // forget params
  };

  return (
    <Nav aria-label="Main navigation" theme="light" onSelect={onSelect} className="main-navigation">
      <NavGroup title="Networking">
        <NavItem preventDefault to="/layer3" itemId="layer3" isActive={activeItem === '/layer3'}>
          TCP/IP
        </NavItem>
        <NavItem preventDefault to="/ingress" itemId="ingress" isActive={activeItem === '/ingress'}>
          Ingress
        </NavItem>
      </NavGroup>
    </Nav>
  );
};
