/* eslint-disable @typescript-eslint/no-explicit-any */

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
window.API_LOGGING = false;

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
const isFrontendLoggingEnabled = () => !!window.API_LOGGING;

export const logFrontendRequest = (url?: string, reqInit?: RequestInit) => {
  if (isFrontendLoggingEnabled()) {
    console.log(`=== Request for ${url || ''}:\n`, reqInit && JSON.stringify(reqInit));
  }
};

export const logFrontendResponse = (url?: string, result?: any) => {
  if (isFrontendLoggingEnabled()) {
    console.log(`=== Response for ${url || ''}:\n`, JSON.stringify(result));
  }
};

if (isFrontendLoggingEnabled()) {
  console.warn(
    'DEBUG BUILD ONLY. For production, turn off extensive logging in the frontendLogging.ts',
  );
}
