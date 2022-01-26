import express from 'express';

import { login, loginCallback, logout } from './k8s/oauth';
import { liveness, ping, proxy, readiness } from './endpoints';

const PORT = process.env.BACKEND_PORT || 3001;

const app = express();

app.get('/ping', ping);
app.get(`/readinessProbe`, readiness)
app.get(`/livenessProbe`, liveness)

app.get(`/login`, login);
app.get(`/login/callback`, loginCallback);
app.get(`/logout`, logout);

app.all(`/api/*`, proxy);

app.listen(PORT, () => {
  console.log(`Server listening on ${PORT}`);
});
