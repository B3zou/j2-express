# J2 — la journée en un coup d'œil

Hier, n'importe qui pouvait créer, modifier ou supprimer une équipe. Ce matin, on ferme la porte : un compte, un
mot de passe **haché**, un jeton **JWT** délivré à la connexion, un middleware `requireAuth` posé sur chaque
écriture. Cet après-midi, on accélère : un cache **Redis** devant les routes coûteuses, avec une durée de vie et
une invalidation à l'écriture. Entre les deux, une démo : le même projet avec un vrai ORM, **Prisma**.

| Moment | Quoi | Support |
|---|---|---|
| Matin | Cours, puis **TD JWT** : bcrypt, login, `requireAuth`, les écritures protégées, ensemble | le TD JWT, au format Word, fourni par l'enseignant |
| Début d'après-midi | **Démo ORM** : le projet réécrit avec Prisma, au vidéoprojecteur | [orm.md](orm.md) |
| Après-midi | Cours, puis **TD Redis** : un cache à la main, le middleware `cached()`, l'invalidation, ensemble | le TD Redis, au format Word, fourni par l'enseignant |
| Fin de journée | `make test`, commit, push | fin du TD Redis |

## Comment travailler

**Tout est un squelette.** Les fichiers existent, les fonctions à écrire sont là avec leur signature, leur contrat
en commentaire et un `TODO n` qui renvoie à l'étape du TD. `grep -rn "TODO" api/src` les liste tous. Vous ne
créez aucun fichier aujourd'hui.

**Chaque étape commence par un temps de réflexion, seul** : lisez le test, répondez aux questions de l'encadré
« À vous », essayez. Ensuite, on construit la solution ensemble au vidéoprojecteur. Si vous êtes en avance, passez
à l'étape suivante ; si vous êtes bloqué, c'est normal, c'est pour ça qu'on la fait ensemble.

Les **bonus** (🔴) sont moins guidés : le test, la cible, trois indices. Pour ceux qui ont fini.

**À midi, tout le monde repart du même point.** L'enseignant pousse la branche `checkpoint-jwt` (le matin,
corrigé). Si vos tests `10` à `12` sont verts, gardez votre branche. Sinon :

```bash
git add -A && git commit -m "fin de matinée"        # gardez votre travail
git fetch upstream
git checkout -b apres-midi upstream/checkpoint-jwt   # repartez du corrigé
make db-reset
```

Les trois réflexes d'hier restent les bons : `make test f=NN` après chaque étape, `make logs` dès que quelque chose
ne répond pas comme prévu, Swagger UI (http://localhost:8000/api/docs) et `curl` pour essayer. **Un commit par
étape**, poussé sur votre fork.

## Les tests sont la spécification

| Fichier | Ce qu'il vérifie | Étape |
|---|---|---|
| `00-games.hurl` | le témoin d'hier ; vert toute la journée (il porte un jeton pré-signé, lisez son en-tête) | — |
| `01` à `05` | les ressources d'hier ; ils **s'authentifient** : rouges tant que `/login` n'existe pas | TD JWT, étape 2 |
| `06-openapi.hurl` | le contrat OpenAPI, Auth comprise (fourni) : vert dès le début | — |
| `10-register.hurl` | le mot de passe est haché et ne sort jamais de l'API | TD JWT, étape 1 |
| `11-login.hurl` | `POST /api/auth/login` délivre un JWT ; 401 identique pour email inconnu et mot de passe faux | TD JWT, étape 2 |
| `12-protected.hurl` | `requireAuth` : `/me`, puis les 12 écritures | TD JWT, étapes 3 et 4 |
| `bonus-13-refresh.hurl` | refresh token, rotation, logout (`make test f=13`) | 🔴 bonus |
| `20-cache-top.hurl` | un cache à la main sur `/api/players/top` : `X-Cache: MISS` puis `HIT` | TD Redis, étape 1 |
| `21-cache-middleware.hurl` | le middleware `cached(ttl)` sur trois routes, la clé triée, jamais un 404 en cache | TD Redis, étape 2 |
| `22-cache-invalidate.hurl` | une écriture sur un joueur ou une équipe vide le cache concerné | TD Redis, étape 3 |
| `23-health.hurl` | `/api/health` dit si Redis répond | TD Redis, étape 4 |
| `bonus-24-ratelimit.hurl` | 5 tentatives de connexion par minute, puis 429 (`make test f=24`) | 🔴 bonus |
| `bonus-25-refresh-redis.hurl` | les refresh tokens dans Redis plutôt qu'en base (`make test f=25`) | 🔴 bonus |

Ce que `make test` doit afficher au fil de la journée :

| Moment | Verts | Rouges |
|---|---|---|
| au départ | `00`, `06` | `01`–`05`, `10`–`12`, `20`–`23`, bonus |
| après l'étape 2 du matin | + `01`–`05`, `10`, `11` | `12`, `20`–`23`, bonus |
| fin de matinée (`checkpoint-jwt`) | `00`–`12` | `20`–`23`, bonus |
| fin de journée | `00`–`23` | bonus (sauf ceux que vous avez faits) |

Aucune requête de ces tests ne doit **jamais** produire un 500 : si c'est le cas, c'est un bug, la cause est dans
`make logs`. `make test f=12` ne lance qu'un fichier ; `make test ERRORS=long` affiche les réponses complètes.

## Le format des erreurs

Le même qu'hier, avec deux codes de plus :

```json
{ "title": "Unauthorized", "status": 401 }
```

| Code | Quand |
|---|---|
| 400 | JSON illisible, ou paramètre de requête invalide (`?limit=abc`) |
| **401** | jeton absent, mal formé, invalide ou expiré ; ou mot de passe faux à la connexion. Toujours avec l'en-tête `WWW-Authenticate: Bearer` |
| 404 | ressource absente, ou identifiant qui n'est pas un nombre |
| 409 | une valeur unique est déjà prise (un nom d'équipe, un email) |
| 415 | une écriture sans `Content-Type: application/json` |
| 422 | le corps est lisible mais ne respecte pas les règles |
| **429** | trop de tentatives de connexion (bonus), avec l'en-tête `Retry-After` |
| 500 | un bug : message générique pour le client, le détail dans `make logs` |

## Antisèches

Nouvelles aujourd'hui :

- [bcrypt et JWT](cheatsheets/jwt-bcrypt.md) : hacher un mot de passe, signer et vérifier un jeton, l'en-tête `Authorization`, 401 ou 403, Swagger et le bouton Authorize.
- [Redis](cheatsheets/redis.md) : les dix commandes utiles, node-redis, les stratégies de cache, les pièges.
- [Prisma](cheatsheets/prisma.md) : le schéma, le client, les requêtes courantes, et l'équivalent avec Sequelize et TypeORM.

Celles d'hier, toujours valables :

- [TypeScript](cheatsheets/typescript.md) · [Express](cheatsheets/express.md) · [pg et zod](cheatsheets/pg-zod.md) · [OpenAPI](cheatsheets/openapi.md) · [HTTP et REST](cheatsheets/http-rest.md)
