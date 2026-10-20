// GET /api/health : l'API répond, la base aussi, et Redis ? (utilisé par Docker pour attendre l'API)
// Redis absent n'est PAS une panne : le cache est un confort, la base est vitale.
import { Router } from 'express';
import { redisStatus } from './cache.js';
import { query } from './db.js';

export const healthRouter = Router();

healthRouter.get('/', async (_req, res) => {
  await query('SELECT 1');
  res.json({ status: 'ok', database: 'ok', redis: await redisStatus() });
});
