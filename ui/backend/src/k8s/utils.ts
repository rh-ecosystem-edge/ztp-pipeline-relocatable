const logger = console;

export const getClusterApiUrl = () => {
  if (!process.env.CLUSTER_API_URL) {
    logger.error('CLUSTER_API_URL env variable is not set.');
  }
  return process.env.CLUSTER_API_URL || '';
};

export const logAllEnvVariables = () => {
  Object.keys(process.env).forEach((key) => {
    logger.log(`${key}: ${process.env[key] || ''}`);
  });
};
