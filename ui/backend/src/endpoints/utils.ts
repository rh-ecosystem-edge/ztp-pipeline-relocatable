export const validateInput = (regexp: RegExp, input?: string) => {
  if (input?.match(regexp)) {
    return input;
  }
  return undefined;
};
