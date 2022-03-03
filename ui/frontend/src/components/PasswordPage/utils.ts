export const isPasswordPolicyLength = (pwd?: string): boolean => !!pwd && pwd.length >= 8;
export const isPasswordPolicyUppercase = (pwd?: string): boolean =>
  !!pwd && pwd.toLocaleLowerCase() !== pwd;

// Do not forget to update PasswordRequirements.tsx as well
export const isPasswordPolicyMet = (pwd?: string): boolean =>
  isPasswordPolicyLength(pwd) && isPasswordPolicyUppercase(pwd);
