import express from 'express';

import { login, loginCallback, logout } from './k8s/oauth';
import { liveness, ping, proxy, readiness, serve } from './endpoints';

const PORT = process.env.BACKEND_PORT || 3001;

const logger = console;

const startUpCheck = () => {
  const requiredEnvVars = [
    // 'BACKEND_PORT',
    'FRONTEND_URL',
    'CLUSTER_API_URL',
    'TOKEN',
    'OAUTH2_CLIENT_ID',
    'OAUTH2_CLIENT_SECRET',
    'OAUTH2_REDIRECT_URL',
  ];
  requiredEnvVars.forEach((env) => {
    if (!process.env[env]) {
      logger.error(`Missing required environment variable ${env}, exiting.`);
      process.exit(1);
    }
  });

  if (!process.env.BACKEND_PORT) {
    console.warn('Optional BACKEND_PORT environment variable is missing, using default: ', PORT)
  }
};

const start = () => {
  startUpCheck();

  const app = express();

  app.get('/ping', ping);
  app.get(`/readinessProbe`, readiness);
  app.get(`/livenessProbe`, liveness);

  app.get(`/login`, login);
  app.get(`/login/callback`, loginCallback);
  app.get(`/logout`, logout);

  app.all(`/api/*`, proxy);

  app.get(`/*`, serve);

  app.listen(PORT, () => {
    logger.info(`Server listening on ${PORT}`);
  });
};

start();
