import { PWD_REGEX } from '../../copy-backend-common';

export const isPasswordPolicyLength = (pwd?: string): boolean => !!pwd && pwd.length >= 8;
export const isPasswordPolicyUppercase = (pwd?: string): boolean =>
  !!pwd && pwd.toLocaleLowerCase() !== pwd;
export const isPasswordPolicyCharSet = (pwd?: string): boolean => !!pwd?.match(PWD_REGEX);

// Do not forget to update PasswordRequirements.tsx as well
export const isPasswordPolicyMet = (pwd?: string): boolean =>
  isPasswordPolicyLength(pwd) && isPasswordPolicyUppercase(pwd) && isPasswordPolicyCharSet(pwd);
