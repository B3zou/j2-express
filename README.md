# GG League · J2 — La même API, sécurisée et mise en cache

Hier, vous avez écrit l'API de la GG League en TypeScript avec Express. Aujourd'hui, vous la **protégez** et vous
l'**accélérez** : des comptes avec un mot de passe haché (bcrypt), une connexion qui délivre un jeton (JWT), un
middleware `requireAuth` qui garde les écritures, puis un cache Redis devant les routes coûteuses, avec une durée
de vie et une invalidation à l'écriture. Entre les deux, une démonstration : le même projet avec un vrai ORM (Prisma).

Ce dépôt contient le **projet complet d'hier** (Game, Team, Player, Match, OpenAPI, tous les tests) plus les
**squelettes** du jour : les fichiers existent, les fonctions à écrire sont là avec leur contrat et un `TODO n`
numéroté qui renvoie à l'étape du TD. Vous complétez, vous ne créez pas de fichier.

```
  navigateur (Swagger UI) ──▶ ┌──────────────────────────────────────┐ ──▶ PostgreSQL 17
  curl, Postman            ──▶ │  api · Node 22 + Express 5 (TypeScript) │
  make test (Hurl)         ──▶ │  http://localhost:8000/api            │ ──▶ Redis 8
                               └──────────────────────────────────────┘
```

Les supports de la journée sont dans [`docs/`](docs/README.md) : le TD du matin (JWT), la démo ORM, le TD de
l'après-midi (Redis), huit antisèches.

## Installation (à faire avant le cours si possible)

### Prérequis

| | Linux | macOS | Windows |
|---|---|---|---|
| Docker | Docker Engine + plugin Compose v2 | Docker Desktop | Docker Desktop **avec WSL 2** |
| Git, make | paquets `git`, `make` | `xcode-select --install` | dans WSL : `sudo apt install git make` |

Sous Windows, travaillez **dans WSL** (terminal Ubuntu) et clonez le dépôt dans le système de fichiers Linux
(`~/…`, pas `/mnt/c/…`). Avant de cloner : `git config --global core.autocrlf input`.

**Rien d'autre à installer** : Node.js et Redis tournent dans Docker. Toutes les bibliothèques de la journée
(`bcryptjs`, `jsonwebtoken`, `redis`) sont déjà dans `package.json` : aucun `npm install` à faire en classe.

### Récupérer le projet

1. Sur GitHub, faites un **fork privé** de ce dépôt et donnez-y accès à l'enseignant.
2. Clonez **votre fork**, puis déclarez le dépôt de l'enseignant comme `upstream` (il servira à midi pour
   récupérer la branche `checkpoint-jwt`, et si un énoncé doit être corrigé) :

```bash
git clone <url de VOTRE fork> j2-express
cd j2-express
git remote add upstream <url du dépôt de l'enseignant>
```

Si le projet d'hier tourne encore sur votre poste, arrêtez-le d'abord (`make down` dans son dossier) : les deux
projets utilisent les mêmes ports par défaut (sauf si vous les avez changés dans `.env`, voir plus bas).

### Vérifier et installer

```bash
make doctor     # vérifie Docker, les ports (8000, 5433, 6379), git, les fins de ligne
make install    # construit l'image, installe les dépendances, crée la base et charge les données de démo
```

Quand c'est terminé :

| | |
|---|---|
| Votre API | http://localhost:8000/api/games |
| Swagger UI (la documentation, pour essayer l'API, avec le bouton **Authorize**) | http://localhost:8000/api/docs |
| PostgreSQL (DBeaver, DataGrip…) | `localhost:5433`, base `app`, utilisateur `app`, mot de passe `app` |
| Redis | `localhost:6379`, ou `make redis-cli` |

```bash
make test       # 00-games et 06-openapi doivent être VERTS ; les autres seront le travail de la journée
```

Si un port est déjà pris, copiez `.env.example` en `.env` et changez `API_PORT`, `DB_PORT` ou `REDIS_PORT`.

## Au quotidien

```bash
make help            # toutes les commandes
make up / make down  # démarrer / arrêter (les données sont conservées)
make logs            # les requêtes, les erreurs et les rechargements, en direct
make typecheck       # vérifier les types (tsc --noEmit), sans lancer le serveur
make test            # tous les tests · make test f=12 · make test ERRORS=long
make db-reset        # recréer les tables (db/schema.sql) et les données de démo (db/seed.sql)
make db-shell        # une console psql
make redis-cli       # une console Redis (KEYS *, GET, TTL…)
make npm c="…"       # npm dans le conteneur
```

Le serveur se **recharge tout seul** à chaque fichier sauvegardé dans `api/src/` (`tsx watch`). Une erreur de
compilation ou une exception au démarrage s'affiche dans `make logs` : c'est le premier endroit où regarder.

## Le code

```
api/
  openapi.yaml           la spécification OpenAPI : complète, Auth comprise (bouton Authorize dans Swagger UI)
  db/schema.sql          les tables d'hier + "user"
  db/seed.sql            les données de démo + un compte : coach@gg-league.dev / coach123
  src/
    app.ts               création de l'app et ORDRE des middlewares (+ /api/auth)
    server.ts            connexion à Redis, puis app.listen()
    cache.ts             le client Redis et les outils du cache          ← TD de l'après-midi (TODO 21-23)
    auth/
      user.schema.ts     types et schémas zod de User (fourni)
      user.repository.ts l'accès à la table "user" (fourni)
      auth.service.ts    bcrypt et JWT                                   ← TD du matin (TODO 1, 2)
      auth.router.ts     /register (fourni, à corriger), /login, /me     ← TD du matin (TODO 1, 3, 5)
    middlewares/
      requireAuth.ts     le middleware qui exige un jeton                ← TD du matin (TODO 4)
    games/ teams/ players/ matches/   les ressources d'hier, complètes   ← TODO 20 (cache), étape 4 (requireAuth)
tests/                   les tests Hurl : la spécification de la journée
docs/                    TD JWT, TD Redis, démo ORM, antisèches
```

`grep -rn "TODO" api/src` liste tout ce qu'il reste à écrire.
