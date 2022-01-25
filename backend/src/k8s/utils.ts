const logger = console;

export const getClusterApiUrl = () => {
  if (!process.env.CLUSTER_API_URL) {
    logger.error('CLUSTER_API_URL env variable is not set.');
  }
  return process.env.CLUSTER_API_URL || '';
};
