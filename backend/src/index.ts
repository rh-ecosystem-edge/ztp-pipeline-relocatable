import express from 'express';

import { login, loginCallback, logout } from './k8s/oauth';
import { ping } from './endpoints/ping';
import { projects } from './endpoints/projects';

const PORT = process.env.BACKEND_PORT || 3001;

const app = express();

app.get("/ping", ping);

app.get(`/login`, login)
app.get(`/login/callback`, loginCallback)
app.get(`/logout`, logout)


app.get("/projects", projects);

app.listen(PORT, () => {
  console.log(`Server listening on ${PORT}`);
});

