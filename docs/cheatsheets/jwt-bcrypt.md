# Antisèche bcrypt et JWT

Deux outils, deux moments : **bcrypt** à l'inscription et à la connexion (le mot de passe), **JWT** à la connexion et
à chaque requête protégée (le jeton). Références : https://github.com/dcodeIO/bcrypt.js ·
https://github.com/auth0/node-jsonwebtoken · https://jwt.io

## bcrypt : hacher un mot de passe

```ts
import bcrypt from 'bcryptjs';

const hash = await bcrypt.hash('correct-horse', 10);   // "$2b$10$N9qo8uLOickgx2ZMRZoMye…" (60 caractères)
await bcrypt.compare('correct-horse', hash);           // true
await bcrypt.compare('wrong', hash);                   // false
```

- **Hacher n'est pas chiffrer** : on ne retrouve jamais le mot de passe à partir du hachage. Pour vérifier, on
  hache le candidat de la même façon et on compare : c'est `compare`.
- Le `10` est le **coût** (2¹⁰ tours) : ~100 ms par hachage. C'est **voulu** : un attaquant qui a volé la base ne
  peut essayer que quelques mots de passe par seconde, contre des milliards avec sha256. Chaque hachage contient un
  **sel** aléatoire : deux comptes avec le même mot de passe ont deux hachages différents.
- bcrypt ignore au-delà de 72 octets : d'où le `max(72)` du schéma zod.
- `bcryptjs` est l'implémentation en JavaScript pur (rien à compiler) ; en production on trouve souvent `bcrypt`
  (natif, plus rapide), **même API**. Alternatives modernes : `argon2`, `scrypt` (`node:crypto`).
- Ce qu'on ne fait **jamais** : stocker le mot de passe, le renvoyer dans une réponse (même haché), le mettre dans
  un log ou dans un jeton.

## JWT : un jeton signé

Un JWT est une chaîne en trois parties séparées par des points : `en-tête.payload.signature`, chacune en base64url.

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 . eyJzdWIiOiIxIiwiZW1haWwiOiJjb2FjaEBnZy1sZWFndWUuZGV2IiwiaWF0IjoxNzYxMDM0MDAwLCJleHAiOjE3NjEwMzc2MDB9 . s3ZkQjKuCqMpOHbT…
{ "alg": "HS256", "typ": "JWT" }   { "sub": "1", "email": "coach@gg-league.dev", "iat": 1761034000, "exp": 1761037600 }   HMAC-SHA256(en-tête.payload, secret)
```

- L'en-tête et le payload sont **lisibles par tous** (collez un jeton sur https://jwt.io). Un JWT n'est pas
  chiffré, il est **signé** : on ne peut pas le modifier sans invalider la signature, parce que la signature exige le
  secret, que seul le serveur connaît.
- Les claims standard : `sub` (subject, l'identifiant, en chaîne), `iat` (issued at), `exp` (expiration), en
  secondes depuis 1970. On ajoute ce qu'on veut (`email`) **sauf** des secrets.
- **Stateless** : le serveur ne garde rien. Vérifier un jeton = vérifier la signature et la date. Conséquence :
  on ne peut pas « déconnecter » un jeton avant son expiration (d'où des durées courtes et le refresh token).

```ts
import jwt from 'jsonwebtoken';

const token = jwt.sign({ sub: '1', email }, process.env.JWT_SECRET!, { algorithm: 'HS256', expiresIn: '1h' });
const payload = jwt.verify(token, process.env.JWT_SECRET!, { algorithms: ['HS256'] }) as jwt.JwtPayload;
payload.sub; payload.email; payload.exp;
jwt.decode(token); // lit SANS vérifier : seulement pour lire iat/exp d'un jeton qu'on vient de signer
```

### Les erreurs de jsonwebtoken

| Erreur | Quand | Réponse |
|---|---|---|
| `jwt.TokenExpiredError` | `exp` est passé | `401 Token expired` |
| `jwt.JsonWebTokenError` | signature fausse, jeton mal formé, algorithme refusé | `401 Invalid token` |
| `jwt.NotBeforeError` | claim `nbf` dans le futur (rare) | `401 Invalid token` |

`TokenExpiredError` hérite de `JsonWebTokenError` : testez-la **en premier** avec `instanceof`.

### Le secret

- Dans l'environnement (`JWT_SECRET` dans `compose.yaml`), jamais en dur dans le code, jamais dans Git.
- En production : long et aléatoire (`openssl rand -base64 48`). Qui a le secret peut fabriquer n'importe quel
  jeton pour n'importe quel utilisateur.
- Toujours fixer `algorithms: ['HS256']` à la vérification : sans cela, un jeton `"alg": "none"` est accepté par
  certaines bibliothèques.

## L'en-tête Authorization

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs…
```

Un schéma (`Bearer`, « porteur » : qui a le jeton a l'accès), un espace, le jeton. Côté serveur :

```ts
const match = /^Bearer (\S+)$/.exec(req.headers.authorization ?? '');
if (!match) throw new HttpError(401, 'Unauthorized');
const token = match[1];
```

Un 401 porte l'en-tête `WWW-Authenticate: Bearer` (RFC 7235) : « voici comment t'authentifier ».

```bash
TOKEN=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"email":"coach@gg-league.dev","password":"coach123"}' http://localhost:8000/api/auth/login | jq -r .accessToken)
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/auth/me | jq
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"name":"Hash Slingers","tag":"HSH","country":"FR"}' http://localhost:8000/api/teams | jq
```

Dans **Swagger UI** : bouton **Authorize** (en haut à droite), collez le `accessToken` **sans** le mot `Bearer`
(Swagger l'ajoute), « Authorize », « Close ». Les routes à cadenas envoient alors l'en-tête.

## 401 ou 403 ?

| | Sens | Exemple |
|---|---|---|
| **401 Unauthorized** | « je ne sais pas qui tu es » : pas de jeton, jeton invalide ou expiré | toute la journée |
| **403 Forbidden** | « je sais qui tu es, et tu n'as pas le droit » | un fan qui veut supprimer une équipe (rôles : pas aujourd'hui) |

## Le middleware, en entier

```ts
export const requireAuth: RequestHandler = (req, res, next) => {
  const match = /^Bearer (\S+)$/.exec(req.headers.authorization ?? '');
  if (!match) throw new HttpError(401, 'Unauthorized');
  res.locals.user = verifyAccessToken(match[1]!); // { id, email } ; lève 401 si expiré ou invalide
  next();
};

// par route, AVANT la validation :
teamRouter.post('/', requireAuth, validate(TeamSchema), handler);
```

Pourquoi par route et pas `app.use(requireAuth)` : les lectures restent publiques. Pourquoi avant `validate` : un
client sans jeton n'a pas à connaître les règles du corps.

## Refresh token (bonus)

Un jeton d'accès court (15 min) + un **refresh token** opaque (64 hex, `randomBytes(32)`), long (7 jours), stocké
**haché** (sha256) côté serveur, donc **révocable** (logout) et **à usage unique** (rotation : chaque refresh en
émet un nouveau et détruit l'ancien). Le JWT reste stateless ; c'est le refresh token qui porte l'état.
