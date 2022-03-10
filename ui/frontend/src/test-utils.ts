export const delay = (ms: number) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

// for jest only. At runtime, this is handled by middleware
export const workaroundUnmarshallObject = (res: unknown) => {
  if (res && typeof res === 'string') {
    return JSON.parse(res);
  }
  return res;
};
