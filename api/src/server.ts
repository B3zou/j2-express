// Point d'entrée : on lance la connexion à Redis (en arrière-plan) et on écoute sur le port.
// L'application elle-même est dans app.ts. Redis absent ne doit jamais empêcher l'API de démarrer.
import app from './app.js';
import { connectRedis } from './cache.js';

const port = Number(process.env.PORT ?? 3000);

connectRedis();

app.listen(port, () => {
  console.log(`API prête sur le port ${port} (http://localhost:${process.env.API_PORT ?? port}/api)`);
});
