import React from 'react';

import { CheckCircleIcon, ExclamationCircleIcon } from '@patternfly/react-icons';
import {
  global_danger_color_100 as dangerColor,
  global_success_color_100 as successColor,
} from '@patternfly/react-tokens';

import { useK8SStateContext } from '../K8SStateContext';

const isPasswordPolicyLength = (pwd?: string): boolean => !!pwd && pwd.length >= 8;
const isPasswordPolicyUppercase = (pwd?: string): boolean =>
  !!pwd && pwd.toLocaleLowerCase() !== pwd;

const PolicyIcon: React.FC<{ policyMet: boolean }> = ({ policyMet }) =>
  policyMet ? (
    <CheckCircleIcon color={successColor.value} />
  ) : (
    <ExclamationCircleIcon color={dangerColor.value} />
  );

export const PasswordRequirements: React.FC = () => {
  const { password } = useK8SStateContext();

  return (
    <ul>
      <li>
        <PolicyIcon policyMet={isPasswordPolicyLength(password)} />
        <span className="password-requirement-text">8 characters minimum</span>
      </li>
      <li className="pf-c-helper-text__item pf-m-dynamic pf-m-error">
        <PolicyIcon policyMet={isPasswordPolicyUppercase(password)} />
        <span className="password-requirement-text">One uppercase character</span>
      </li>
    </ul>
  );
};
