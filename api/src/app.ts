// Création de l'application Express et ORDRE des middlewares : l'ordre des app.use() est l'ordre
// d'exécution. Le serveur (app.listen) est dans server.ts, pour pouvoir importer l'app sans ouvrir de port.
import express from 'express';
import { authRouter } from './auth/auth.router.js';
import { docsRouter } from './docs.router.js';
import { gameRouter } from './games/game.router.js';
import { healthRouter } from './health.router.js';
import { matchRouter } from './matches/match.router.js';
import { errorHandler } from './middlewares/errorHandler.js';
import { notFound } from './middlewares/notFound.js';
import { requestLogger } from './middlewares/requestLogger.js';
import { requireJson } from './middlewares/requireJson.js';
import { playerRouter } from './players/player.router.js';
import { teamRouter } from './teams/team.router.js';

const app = express();

// 0. En tout premier : voir passer TOUTES les requêtes, même celles qui finiront en 404 ou en erreur.
app.use(requestLogger);

// 1. Lire les corps JSON dans req.body (sinon req.body vaut undefined). JSON illisible → erreur 400.
app.use(express.json());
// 2. Une écriture sans Content-Type: application/json → 415, avant même d'atteindre une route.
app.use(requireJson);

// 3. Les routeurs : un par ressource, monté sous son préfixe.
//    Le J2 ajoute /api/auth. La protection des routes (requireAuth) ne se pose PAS ici en app.use() :
//    les lectures restent publiques, seules les écritures exigent un jeton → middleware par route (étape 4).
app.use('/api/health', healthRouter);
app.use('/api', docsRouter); // /api/docs (Swagger UI) et /api/openapi.json
app.use('/api/auth', authRouter);
app.use('/api/games', gameRouter);
app.use('/api/teams', teamRouter);
app.use('/api/players', playerRouter);
app.use('/api/matches', matchRouter);

// 4. Aucune route n'a répondu → 404 en JSON.
app.use(notFound);
// 5. Toujours en dernier, 4 paramètres : transforme toute erreur en réponse JSON.
app.use(errorHandler);

export default app;
