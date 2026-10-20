// Les routes de Game : lire la requête, appeler le repository, choisir le code de statut.
// Hier : GameController, 130 lignes. Pas de SQL ici, pas d'Express dans le repository.
import { Router } from 'express';
import { HttpError } from '../errors.js';
import { parseId } from '../middlewares/params.js';
import { requireAuth } from '../middlewares/requireAuth.js';
import { validate, validateQuery } from '../middlewares/validate.js';
import { games } from './game.repository.js';
import { GamePatchSchema, GameQuerySchema, GameSchema, type GameInput, type GameQuery } from './game.schema.js';

export const gameRouter = Router();

// GET /api/games[?genre=fps]            hier : GameController::list()
gameRouter.get('/', validateQuery(GameQuerySchema), async (_req, res) => {
  const { genre } = res.locals.query as GameQuery;
  res.json(genre ? await games.findByGenre(genre) : await games.findAll(1, 100));
});

// GET /api/games/:id                    hier : GameController::show()
gameRouter.get('/:id', async (req, res) => {
  const game = await games.findOne(parseId(req.params.id, 'Game'));
  if (!game) throw new HttpError(404, 'Game not found');
  res.json(game);
});

// POST /api/games                       hier : GameController::create()
gameRouter.post('/', requireAuth, validate(GameSchema), async (req, res) => {
  const game = await games.insert(req.body as GameInput);
  res.status(201).location(`/api/games/${game.id}`).json(game);
});

// PATCH /api/games/:id                  hier : GameController::update()
gameRouter.patch('/:id', requireAuth, validate(GamePatchSchema), async (req, res) => {
  const game = await games.update(parseId(req.params.id, 'Game'), req.body as Partial<GameInput>);
  if (!game) throw new HttpError(404, 'Game not found');
  res.json(game);
});

// DELETE /api/games/:id                 hier : GameController::delete()
gameRouter.delete('/:id', requireAuth, async (req, res) => {
  const deleted = await games.delete(parseId(req.params.id, 'Game'));
  if (!deleted) throw new HttpError(404, 'Game not found');
  res.sendStatus(204);
});
