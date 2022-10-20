import { PWD_REGEX, USERNAME_REGEX } from '../../copy-backend-common';

export const isPasswordPolicyLength = (pwd?: string): boolean => !!pwd && pwd.length >= 8;
export const isPasswordPolicyUppercase = (pwd?: string): boolean =>
  !!pwd && pwd.toLocaleLowerCase() !== pwd;
export const isPasswordPolicyCharSet = (pwd?: string): boolean => !!pwd?.match(PWD_REGEX);

// Do not forget to update PasswordRequirements.tsx as well
export const isPasswordPolicyMet = (pwd?: string): boolean =>
  isPasswordPolicyLength(pwd) && isPasswordPolicyUppercase(pwd) && isPasswordPolicyCharSet(pwd);

export const usernameValidator = (username = ''): string => {
  if (username.length >= 54) {
    return 'Valid username can not be longer than 54 characters.';
  }

  if (username === 'kubeadmin') {
    return 'The kubeadmin username is reserved.';
  }

  if (!username || username.match(USERNAME_REGEX)) {
    return ''; // passed
  }

  return "Valid username wasn't provided.";
};

export const passwordValidator = (pwd: string): boolean => {
  return isPasswordPolicyMet(pwd);
};
