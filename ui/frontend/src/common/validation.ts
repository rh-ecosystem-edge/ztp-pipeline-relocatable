export const USERNAME_REGEX = /^[a-z]([-a-z0-9]*[a-z0-9])?$/;
export const PWD_REGEX = /^[a-zA-Z]([-a-z-A-Z0-9]*[a-zA-Z0-9])?$/;

// https://stackoverflow.com/questions/10306690/what-is-a-regular-expression-which-will-match-a-valid-domain-name-without-a-subd
export const DNS_NAME_REGEX =
  /^(((?!\\-))(xn\\-\\-)?[a-z0-9\-_]{0,61}[a-z0-9]{1,1}\.)*(xn\\-\\-)?([a-z0-9\\-]{1,61}|[a-z0-9\\-]{1,30})\.[a-z]{2,}$/;
