# Antisèche Redis

Redis est une base **clé → valeur en mémoire** : très rapide, avec des durées de vie sur les clés. On l'utilise
comme cache, comme compteur, comme file, comme store de sessions. Références : https://redis.io/commands ·
https://github.com/redis/node-redis

## Les dix commandes utiles (`make redis-cli`)

| Commande | Effet |
|---|---|
| `SET k v` · `SET k v EX 60` | écrire (avec une durée de vie de 60 s) |
| `GET k` | lire ; `(nil)` si la clé n'existe pas (ou a expiré) |
| `DEL k [k2…]` | supprimer |
| `EXPIRE k 60` · `TTL k` | donner une durée de vie ; lire les secondes restantes (`-1` : sans limite, `-2` : absente) |
| `INCR k` · `INCRBY k 5` | incrémenter un compteur (crée la clé à 0 si besoin), renvoie la nouvelle valeur |
| `GETDEL k` | lire **et** supprimer, en une seule commande atomique |
| `KEYS motif*` | lister les clés… **jamais en production** (parcourt tout, bloque le serveur) |
| `SCAN 0 MATCH motif* COUNT 100` | lister par paquets, sans bloquer : ce qu'on utilise dans le code |
| `SELECT 1` · `FLUSHDB` | changer de base (0 à 15) ; vider la base courante |
| `PING` · `INFO memory` | « tu es là ? » ; l'état du serveur |

Tout est une chaîne. Un objet se stocke avec `JSON.stringify`, se relit avec `JSON.parse` (ou se renvoie tel quel
au client, c'est déjà du JSON).

## node-redis en cinq appels

```ts
import { createClient } from 'redis';

export const redis = createClient({ url: process.env.REDIS_URL, disableOfflineQueue: true });
redis.on('error', (err) => console.error(`Redis : ${err.message}`));
await redis.connect();

await redis.set('cache:/api/teams', JSON.stringify(teams), { EX: 30 });  // SET … EX 30
const hit = await redis.get('cache:/api/teams');                           // string | null
await redis.del(['cache:a', 'cache:b']);
const n = await redis.incr('ratelimit:login:1.2.3.4:ana@test.dev');       // number
await redis.expire(key, 60); const ttl = await redis.ttl(key);
const value = await redis.getDel(key);                                     // string | null
for await (const keys of redis.scanIterator({ MATCH: 'cache:/api/players*', COUNT: 100 })) {
  if (keys.length) await redis.del(keys);                                  // keys : string[] (un paquet)
}
```

- `disableOfflineQueue: true` : si Redis est injoignable, une commande **échoue tout de suite** (promesse rejetée)
  au lieu d'attendre la reconnexion. Sans cela, la requête HTTP attend… indéfiniment.
- `redis.on('error', …)` : obligatoire. Un événement `error` sans écouteur est une exception non rattrapée : Node
  s'arrête.
- Le client se reconnecte tout seul quand Redis revient.

## Le cache HTTP : trois stratégies, dans l'ordre

1. **TTL** (durée de vie) : la réponse est bonne pendant N secondes, puis on la recalcule. Simple ; tolère des
   données un peu vieilles. `SET … EX N`.
2. **Invalidation à l'écriture** : quand la donnée change, on supprime les clés concernées. Fraîcheur immédiate ;
   il faut savoir **quelles** clés dépendent de quoi (le `versus` dépend des joueurs…).
3. **Les deux** : TTL comme filet de sécurité, invalidation pour la fraîcheur. C'est le TD.

Le schéma **cache-aside** (ce qu'on écrit) :

```
lire le cache ──HIT──▶ répondre
     │
    MISS ──▶ lire la base ──▶ répondre ──▶ écrire le cache (EX ttl)
```

### Intercepter `res.json` dans un middleware

Au MISS, le middleware doit laisser la route répondre, mais **voir passer** la réponse pour la stocker :

```ts
const originalJson = res.json.bind(res);
res.json = (body: unknown) => {
  if (res.statusCode === 200) redis.set(key, JSON.stringify(body), { EX: ttl }).catch(() => undefined);
  return originalJson(body);
};
next();
```

Le `.catch(() => undefined)` : on n'attend pas Redis et une erreur Redis ne casse pas la réponse.

## Les pièges

- **Oublier la query dans la clé** : `?limit=3` et `?limit=2` servis depuis la même entrée. Clé = chemin + query ;
  trier la query (`URLSearchParams.sort()`) pour que l'ordre des paramètres ne compte pas.
- **Mettre un 404 (ou un 500) en cache** : une équipe créée juste après resterait « introuvable » 60 s. Ne stocker
  que les 200.
- **`KEYS` en production** : O(n) sur toute la base, bloquant. `SCAN` (via `scanIterator`) parcourt par paquets.
- **Faire dépendre l'API de Redis** : un cache est un confort. `try/catch` ou `.catch()` autour de chaque appel,
  `disableOfflineQueue`, et `/api/health` qui dit `redis: "down"` sans tomber.
- **Un cache sans invalidation sur des données qui changent** : l'utilisateur crée un joueur et ne le voit pas dans
  le classement. Frustrant, et difficile à déboguer (« ça marche, parfois »).
- **Mettre en cache une réponse personnalisée** (qui dépend du jeton) sous une clé commune : tout le monde voit les
  données du premier. Aujourd'hui, seules des lectures publiques sont cachées.

## Au-delà du cache

- **Rate limiting** (bonus) : `INCR` + `EXPIRE`, fenêtre fixe. Variante plus douce : fenêtre glissante avec un
  sorted set (`ZADD`/`ZREMRANGEBYSCORE`).
- **Sessions / refresh tokens** (bonus) : `SET refresh:<hash> <userId> EX 604800`, `GETDEL` pour consommer.
- **Files et pub/sub** : `LPUSH`/`BRPOP`, `PUBLISH`/`SUBSCRIBE`. Pas aujourd'hui.
- **Persistance** : Redis peut écrire sur disque (RDB, AOF), mais on le traite comme **volatile** : tout ce qu'il
  contient doit pouvoir être reconstruit.
