const logger = console;

export const getClusterApiUrl = () => {
  // https://kubernetes.default.svc:443
  return (
    process.env.CLUSTER_API_URL ||
    `https://${process.env.KUBERNETES_SERVICE_HOST || 'missing-KUBERNETES_SERVICE_HOST'}:${
      process.env.KUBERNETES_SERVICE_PORT || 'missing-KUBERNETES_SERVICE_PORT'
    }`
  );
};

export const logAllEnvVariables = () => {
  Object.keys(process.env).forEach((key) => {
    logger.log(`${key}: ${process.env[key] || ''}`);
  });
};
