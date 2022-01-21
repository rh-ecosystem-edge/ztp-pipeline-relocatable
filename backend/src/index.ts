import express from 'express';

const PORT = process.env.PORT || 3001;

const app = express();

app.get("/ping", (_, res) => {
  res.json({ message: "Hello from server 3!" });
});

app.listen(PORT, () => {
  console.log(`Server listening on ${PORT}`);
});

