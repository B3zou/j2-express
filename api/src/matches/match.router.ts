// Les routes de Match, dont l'action POST /api/matches/:id/play qui appelle le simulateur fourni.
import { Router } from 'express';
import { HttpError } from '../errors.js';
import { parseId } from '../middlewares/params.js';
import { requireAuth } from '../middlewares/requireAuth.js';
import { validate, validateQuery } from '../middlewares/validate.js';
import { teams } from '../teams/team.repository.js';
import { matches } from './match.repository.js';
import { MatchQuerySchema, MatchSchema, SeedQuerySchema, type MatchInput, type MatchQuery, type SeedQuery } from './match.schema.js';
import { simulate } from './simulator.js';

export const matchRouter = Router();

// GET /api/matches[?status=scheduled|played]
matchRouter.get('/', validateQuery(MatchQuerySchema), async (_req, res) => {
  const { status } = res.locals.query as MatchQuery;
  res.json(await matches.findByStatus(status));
});

// GET /api/matches/:id
matchRouter.get('/:id', async (req, res) => {
  const match = await matches.findView(parseId(req.params.id, 'Match'));
  if (!match) throw new HttpError(404, 'Match not found');
  res.json(match);
});

// POST /api/matches { teamAId, teamBId } : programmé, pas encore joué
matchRouter.post('/', requireAuth, validate(MatchSchema), async (req, res) => {
  const { id } = await matches.insert(req.body as MatchInput);
  res.status(201).location(`/api/matches/${id}`).json(await matches.findView(id));
});

// POST /api/matches/:id/play[?seed=42] : on joue le match et on enregistre le résultat
matchRouter.post('/:id/play', requireAuth, validateQuery(SeedQuerySchema), async (req, res) => {
  const id = parseId(req.params.id, 'Match');
  const { seed } = res.locals.query as SeedQuery;
  const match = await matches.findView(id);
  if (!match) throw new HttpError(404, 'Match not found');
  if (match.status === 'played') throw new HttpError(409, 'Match already played');

  const ratingA = await teams.ratingOf(match.teamA.id);
  if (ratingA === null) throw new HttpError(422, 'Validation Failed', [{ path: 'teamAId', message: 'team has no players' }]);
  const ratingB = await teams.ratingOf(match.teamB.id);
  if (ratingB === null) throw new HttpError(422, 'Validation Failed', [{ path: 'teamBId', message: 'team has no players' }]);

  const result = simulate({ ...match.teamA, rating: ratingA }, { ...match.teamB, rating: ratingB }, seed);
  if (!(await matches.recordResult(id, result))) throw new HttpError(409, 'Match already played');
  res.json(await matches.findView(id));
});

// DELETE /api/matches/:id
matchRouter.delete('/:id', requireAuth, async (req, res) => {
  const deleted = await matches.delete(parseId(req.params.id, 'Match'));
  if (!deleted) throw new HttpError(404, 'Match not found');
  res.sendStatus(204);
});
