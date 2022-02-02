import express from 'express';
import https from 'https';
import fs from 'fs';

import { login, loginCallback, logout } from './k8s/oauth';
import { liveness, ping, proxy, readiness, SA_TOKEN_FILE, serve } from './endpoints';

const PORT = process.env.BACKEND_PORT || 3001;

const logger = console;

const startUpCheck = () => {
  const requiredEnvVars = [
    // 'BACKEND_PORT',
    // 'TOKEN',
    'FRONTEND_URL',
    'CLUSTER_API_URL',
    'OAUTH2_CLIENT_ID',
    'OAUTH2_CLIENT_SECRET',
    'OAUTH2_REDIRECT_URL',
  ];

  requiredEnvVars.forEach((env) => {
    if (!process.env[env]) {
      logger.error(`Missing required environment variable ${env}, exiting.`);

      // logger.log('TODO: remove following logging:');
      // logAllEnvVariables();

      process.exit(1);
    }
  });

  if (!process.env.BACKEND_PORT) {
    console.warn('Optional BACKEND_PORT environment variable is missing, using default: ', PORT);
  }

  if (!process.env.TOKEN) {
    console.warn(
      'Optional TOKEN environment variable is missing, excpecting it in ',
      SA_TOKEN_FILE,
    ),
      '. Used for liveness probe.';
  }
};

const start = () => {
  startUpCheck();

  const key = fs.readFileSync(process.env.TLS_KEY_FILE || '/app/certs/tls.key');
  const cert = fs.readFileSync(process.env.TLS_CERT_FILE || '/app/certs/tls.crt');
  const options = {
    key: key,
    cert: cert,
  };

  const app = express();

  app.get('/ping', ping);
  app.get(`/readinessProbe`, readiness);
  app.get(`/livenessProbe`, liveness);

  app.get(`/login`, login);
  app.get(`/login/callback`, loginCallback);
  app.get(`/logout`, logout);

  app.all(`/api/*`, proxy);

  app.get(`/*`, serve);

  const server = https.createServer(options, app);
  server.listen(PORT, () => {
    logger.info(`HTTPS server listening on ${PORT}`);
  });
};

start();
