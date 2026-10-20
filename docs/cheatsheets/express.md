# Antisèche Express 5

Express ne fait que deux choses : le routage et la chaîne de middlewares. Tout le reste (validation, base, documentation) est branché par vous, dans l'ordre que vous choisissez. Référence : https://expressjs.com/en/5x/api.html

## L'application et les routeurs

```ts
// src/app.ts (forme réduite ; le vrai fichier est commenté ligne à ligne)
import express from 'express';
import { gameRouter } from './games/game.router.js';
import { errorHandler } from './middlewares/errorHandler.js';
import { notFound } from './middlewares/notFound.js';
import { requireJson } from './middlewares/requireJson.js';

const app = express();
app.use(express.json());             // lit les corps JSON → req.body
app.use(requireJson);                // 415 si une écriture n'annonce pas du JSON
app.use('/api/games', gameRouter);   // monte un routeur sous un préfixe
app.use(notFound);                   // 404 JSON pour tout ce qui n'a pas répondu
app.use(errorHandler);               // toujours en dernier, 4 paramètres
export default app;                  // server.ts : app.listen(port)
```

```ts
// src/games/game.router.ts (forme réduite)
import { Router } from 'express';
import { HttpError } from '../errors.js';
import { parseId } from '../middlewares/params.js';
import { validate } from '../middlewares/validate.js';
import { games } from './game.repository.js';
import { GameSchema, type GameInput } from './game.schema.js';

export const gameRouter = Router();

gameRouter.get('/', async (_req, res) => {                           // GET /api/games
  res.json(await games.findAll(1, 100));
});
gameRouter.get('/:id', async (req, res) => {                         // GET /api/games/:id
  const game = await games.findOne(parseId(req.params.id, 'Game'));
  if (!game) throw new HttpError(404, 'Game not found');
  res.json(game);
});
gameRouter.post('/', validate(GameSchema), async (req, res) => {     // POST /api/games
  const game = await games.insert(req.body as GameInput);
  res.status(201).location(`/api/games/${game.id}`).json(game);
});
```

Les routes sont essayées **dans l'ordre de déclaration** : une route fixe (`/top`) se déclare **avant** `/:id`, sinon `top` est pris pour un id. Chaque nouvelle ressource = un dossier (`router`, `repository`, `schema`) + une ligne `app.use('/api/…', …)` dans `app.ts`, après `games`.

## req et res

| Lire la requête | Type | Notes |
|---|---|---|
| `req.params.id` | `string` | `/api/games/:id` → `'3'` ; convertir avec `parseId(req.params.id, 'Game')` (404 si pas un entier positif) |
| `req.query.genre` | `string \| string[] \| … \| undefined`, **lecture seule** | `?genre=fps` ; valider avec `validateQuery(schema)` → résultat typé dans `res.locals.query` |
| `req.body` | `any` | rempli par `express.json()` ; `undefined` sans corps JSON ; après `validate(schema)` : les données nettoyées |
| `req.get('Content-Type')` | `string \| undefined` | lire un en-tête (insensible à la casse) |
| `req.is('application/json')`, `req.method`, `req.originalUrl` | | le corps annoncé est-il de ce type ? ; `'POST'` ; `'/api/games/3?x=1'` |

| Répondre | Effet |
|---|---|
| `res.json(obj)` | sérialise, pose `Content-Type: application/json`, statut 200 par défaut |
| `res.status(201).json(obj)` | changer le statut (chaînable) |
| `res.sendStatus(204)` | statut seul, sans corps (DELETE) |
| `res.location('/api/games/6')` | pose l'en-tête `Location` (chaînable, avant `.json()`) |
| `res.set('X-Total-Count', String(total))` | n'importe quel en-tête ; la valeur est une chaîne |

Une seule réponse par requête : après `res.json()`, `return` (ou plus rien).

## La chaîne de middlewares

```
Requête → (votre requestLogger, TD étape 1) → express.json() → requireJson → /api/health → /api/docs → /api/games → (vos routeurs) → notFound → errorHandler
```

- Un middleware est une fonction `(req, res, next)`. Il **répond** (`res.json…`) **ou** appelle **`next()`** : jamais les deux, jamais aucun des deux.
- L'ordre des `app.use()` **est** l'ordre d'exécution. Un handler qui répond arrête la chaîne ; si aucune route ne correspond, la requête « tombe » jusqu'à `notFound`.
- `app.use(fn)` : toutes les requêtes. `app.use('/api/games', fn)` : sous un préfixe. `router.post('/', fn1, fn2, handler)` : sur une seule route, dans l'ordre.
- `next(err)`, ou une exception (même dans un `async`, Express 5) : saut direct au middleware d'erreur.

## Écrire un middleware

```ts
// src/middlewares/requireJson.ts (le fichier du squelette)
import type { Request, Response, NextFunction } from 'express';

export function requireJson(req: Request, res: Response, next: NextFunction) {
  const writes = ['POST', 'PUT', 'PATCH'];
  // Un POST « action » (POST /api/matches/3/play) n'a pas de corps : rien à vérifier.
  // Swagger UI et les navigateurs envoient alors Content-Length: 0 → on regarde la taille annoncée.
  const hasBody = req.headers['transfer-encoding'] !== undefined || Number(req.headers['content-length'] ?? 0) > 0;
  if (writes.includes(req.method) && hasBody && !req.is('application/json')) {
    res.status(415).json({ title: 'Unsupported Media Type', status: 415 });
    return; // on répond : on n'appelle pas next()
  }
  next(); // sinon : on passe la main
}
```

Une **fabrique** : une fonction qui reçoit un paramètre et renvoie un middleware configuré. Même forme que `validate(schema)` aujourd'hui et `requireRole('admin')` au J2.

```ts
import type { RequestHandler } from 'express';

export function requireHeader(name: string): RequestHandler {
  return (req, res, next) => {
    if (!req.get(name)) {
      res.status(400).json({ title: `En-tête ${name} manquant`, status: 400 });
      return;
    }
    next();
  };
}
// router.post('/', requireHeader('X-Request-Id'), handler);
```

## `res.locals` et `res.on('finish')`

```ts
// res.locals : un objet libre, propre à la requête, pour passer une donnée d'un middleware au handler
// (la query validée aujourd'hui, l'utilisateur connecté au J2).
gameRouter.get('/', validateQuery(GameQuerySchema), async (_req, res) => {
  const { genre } = res.locals.query as GameQuery;
  res.json(genre ? await games.findByGenre(genre) : await games.findAll(1, 100));
});
```

```ts
// Un middleware qui enrichit la requête puis passe la main : un identifiant par requête.
import type { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'node:crypto';

export function requestId(req: Request, res: Response, next: NextFunction) {
  const id = req.get('X-Request-Id') ?? randomUUID();
  res.locals.requestId = id; // lisible par les middlewares et handlers suivants
  res.set('X-Request-Id', id); // un en-tête se pose AVANT que la réponse parte
  next();
}
```

```ts
// res.on('finish') : appelé quand la réponse est partie. res.statusCode est alors connu, et
// performance.now() permet de mesurer une durée depuis le début du middleware.
res.on('finish', () => {
  console.log(`terminé avec le statut ${res.statusCode}`);
});
```
Dans `finish`, il est **trop tard** pour poser un en-tête (la réponse est envoyée) : un `X-Response-Time` doit être posé avant que le handler réponde (c'est le piège du bonus).

## Les erreurs

```ts
// src/errors.ts
export interface FieldError { path: string; message: string }
export class HttpError extends Error {
  constructor(public status: number, message: string, public errors?: FieldError[]) {
    super(message);
  }
}
// dans un handler :
throw new HttpError(404, 'Game not found');
throw new HttpError(409, 'Conflict', [{ path: 'name', message: 'already exists' }]);
```

```ts
// src/middlewares/errorHandler.ts (forme réduite : celle des diapos)
import type { ErrorRequestHandler } from 'express';

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  const status: number = err.status ?? 500;       // HttpError, express.json() (400)…
  if (status === 500) console.error(err);         // le détail reste côté serveur
  res.status(status).json({ title: status === 500 ? 'Internal Server Error' : err.message, status });
};
```
Celui du squelette fait en plus : `SyntaxError` d'`express.json()` → 400, `ZodError` → 422, erreur PostgreSQL (`translatePgError`) → 409 ou 422, et ajoute `errors` quand l'`HttpError` en porte. Format de toute erreur : `{ title, status, errors?: [{ path, message }] }`. Qui produit quel code : voir l'antisèche HTTP.

## Pièges (à vérifier dans cet ordre)

| Symptôme | Cause |
|---|---|
| `req.body` vaut `undefined` | `express.json()` absent ou monté après les routes, ou requête sans `Content-Type: application/json` |
| toutes les routes répondent 404 | `notFound` monté avant les routeurs ; routeur non monté dans `app.ts` ; mauvais préfixe |
| erreurs renvoyées en HTML | pas de middleware d'erreur, ou pas en dernier, ou 3 paramètres au lieu de 4 |
| la requête ne répond jamais | ni réponse ni `next()` dans un middleware |
| « Cannot set headers after they are sent to the client » | réponse envoyée deux fois : `res.json()` puis `next()`, ou `return` oublié avant un second `res.json()` |
| erreur dans une fonction `async` ignorée | Express 4 : `next(err)` oublié dans le `catch` |
| `GET /api/players/top` répond « Player not found » | `/top` déclaré après `/:id` |
| `req.query.page = 1` plante | `req.query` est en lecture seule en Express 5 : rangez le résultat dans `res.locals` |

## Express 4 et Express 5

| | Express 4 | Express 5 (le squelette) |
|---|---|---|
| Erreur dans un handler `async` | `try/catch` + `next(err)` obligatoires | transmise automatiquement au middleware d'erreur |
| Joker dans un chemin | `/files/*` | `/files/*splat` (nommé) |
| Paramètre facultatif | `/:file.:ext?` | `/:file{.:ext}` (accolades) |
| Expression régulière dans la chaîne du chemin | `/:id(\d+)` | refusée (ReDoS) : valider dans le handler |
| `req.body` quand aucun corps n'est lu | `{}` (si un parseur est monté) | `undefined` |
| `req.query` | modifiable, parseur « étendu » | lecture seule, parseur « simple » |

```ts
// Express 4 : à savoir reconnaître, et écrire si le partiel est en 4
router.get('/:id', async (req, res, next) => {
  try {
    const game = await games.findOne(Number(req.params.id));
    if (!game) return next(new HttpError(404, 'Game not found'));
    res.json(game);
  } catch (err) {
    next(err);
  }
});
```

## Lire `make logs`

```
api-1  | API prête sur le port 3000 (http://localhost:8000/api)      ← (re)démarrage, après chaque sauvegarde
api-1  | GET /api/games/3 → 200 (4.2 ms)                             ← une ligne par requête (requestLogger)
api-1  | POST /api/games → 422 (3.1 ms)
api-1  | Error: Cannot find module '/app/src/games/game.schema'      ← import sans .js (ou fichier mal nommé)
api-1  | error: relation "team" does not exist                       ← PostgreSQL : table absente → make db-reset
api-1  | TypeError: Cannot read properties of null (reading 'name')  ← une 500 : la trace suit, cherchez la ligne « at …/src/… »
```
- `make logs s=api` : seulement l'API ; `Ctrl+C` sort de l'affichage (le serveur continue). Une 500 affiche la trace complète (`console.error(err)` dans `errorHandler`) ; les 4xx n'affichent que la ligne du logger.
- `tsx` ne signale pas les erreurs de **types** : c'est `make typecheck`. Après une erreur de syntaxe, corrigez et sauvegardez : `tsx watch` réessaie ; s'il reste muet, `make restart`.
