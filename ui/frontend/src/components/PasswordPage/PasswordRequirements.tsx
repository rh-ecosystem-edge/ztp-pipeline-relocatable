import React from 'react';

import { CheckCircleIcon, ExclamationCircleIcon } from '@patternfly/react-icons';
import {
  global_danger_color_100 as dangerColor,
  global_success_color_100 as successColor,
} from '@patternfly/react-tokens';

import { useK8SStateContext } from '../K8SStateContext';
import {
  isPasswordPolicyCharSet,
  isPasswordPolicyLength,
  isPasswordPolicyUppercase,
} from './utils';

const PolicyIcon: React.FC<{ idPrefix: string; policyMet: boolean }> = ({ idPrefix, policyMet }) =>
  policyMet ? (
    <CheckCircleIcon color={successColor.value} data-testid={`${idPrefix}-ok`} />
  ) : (
    <ExclamationCircleIcon color={dangerColor.value} data-testid={`${idPrefix}-failed`} />
  );

export const PasswordRequirements: React.FC = () => {
  const { password } = useK8SStateContext();

  return (
    <ul>
      <li>
        <PolicyIcon policyMet={isPasswordPolicyLength(password)} idPrefix="requirement-length" />
        <span className="password-requirement-text">8 characters minimum</span>
      </li>
      <li className="pf-c-helper-text__item pf-m-dynamic pf-m-error">
        <PolicyIcon
          policyMet={isPasswordPolicyUppercase(password)}
          idPrefix="requirement-uppercase"
        />
        <span className="password-requirement-text">One uppercase letter</span>
      </li>
      <li className="pf-c-helper-text__item pf-m-dynamic pf-m-error">
        <PolicyIcon policyMet={isPasswordPolicyCharSet(password)} idPrefix="requirement-charset" />
        <span className="password-requirement-text">
          Leading letter, otherwise a-Z, numbers or special (#?!@$%^&amp;*-)
        </span>
      </li>
    </ul>
  );
};
