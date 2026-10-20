# Antisèche HTTP et REST

Ce qu'il faut savoir d'HTTP pour écrire l'API et lire les tests Hurl, qui sont la spécification de la journée. Références : MDN https://developer.mozilla.org/fr/docs/Web/HTTP · Hurl https://hurl.dev/docs/

## Anatomie d'un échange

```http
PATCH /api/games/3 HTTP/1.1                        ← ligne de requête : méthode, cible (chemin + query), version
Host: localhost:8000                               ← en-têtes
Content-Type: application/json
                                                   ← ligne vide
{"teamSize": 2}                                    ← corps (facultatif)
```
```http
HTTP/1.1 200 OK                                    ← ligne de statut : version, code, raison
Content-Type: application/json; charset=utf-8

{"id": 3, "name": "Rocket League", "genre": "sports", "teamSize": 2}
```

URL : `http://localhost:8000/api/games?genre=fps&page=2` = schéma · hôte · port · chemin `/api/games` · query `genre=fps&page=2`. Côté Express : `req.params` (le `:id` du chemin), `req.query`, `req.body`, `req.get(nom)`.

## Méthodes

| Méthode | Rôle | Sûre | Idempotente | Corps | Succès | Express |
|---|---|---|---|---|---|---|
| `GET` | lire | oui | oui | non | `200` | `router.get` |
| `POST` | créer dans une collection, ou action | non | non | oui (sauf action) | `201` + `Location` (action : `200`) | `router.post` |
| `PATCH` | modifier partiellement | non | non | oui | `200` | `router.patch` |
| `PUT` | remplacer entièrement (pas utilisé aujourd'hui) | non | oui | oui | `200` | `router.put` |
| `DELETE` | supprimer | non | oui | non | `204` | `router.delete` |

**Sûre** = ne modifie rien. **Idempotente** = répéter N fois laisse le serveur dans le même état (la réponse peut changer : `DELETE` → `204` puis `404`).

## Codes de statut du cours

| Code | Nom | Quand | Qui le produit dans le squelette |
|---|---|---|---|
| `200` | OK | lecture, PATCH, action réussie | `res.json()` |
| `201` | Created | POST qui crée ; en-tête `Location` | `res.status(201).location(url).json()` |
| `204` | No Content | succès sans corps (DELETE) | `res.sendStatus(204)` |
| `400` | Bad Request | requête **illisible** : JSON cassé, `?page=abc` | `express.json()` → `errorHandler` ; `validateQuery(schema)` |
| `404` | Not Found | ressource absente, `:id` non numérique, URL inconnue | `HttpError(404, …)`, `parseId`, `notFound` |
| `409` | Conflict | doublon (contrainte UNIQUE), action déjà faite | PostgreSQL `23505` → `translatePgError` ; `HttpError(409, …)` |
| `415` | Unsupported Media Type | écriture sans `Content-Type: application/json` | `requireJson` |
| `422` | Unprocessable Content | lisible mais **invalide** : règle zod ou métier | `validate(schema)`, `HttpError(422, …)` |
| `500` | Internal Server Error | bug : jamais « normal » ; la trace est dans `make logs` | `errorHandler` |

Demain : `401` Unauthorized (pas de jeton) et `403` Forbidden (pas le droit). Familles : `2xx` succès · `4xx` faute du client · `5xx` faute du serveur. Jamais d'erreur dans un `200`.

Format de toutes les erreurs : `{ "title": "Validation Failed", "status": 422, "errors": [{ "path": "teamSize", "message": "…" }] }` (`errors` seulement pour 400, 409 et 422).

## En-têtes

| En-tête | Sens | Exemple |
|---|---|---|
| `Content-Type` | format du corps **envoyé** (requête comme réponse) | `Content-Type: application/json` |
| `Accept` | formats souhaités en réponse | `Accept: application/json` |
| `Location` | URI de la ressource créée (`201`) | `Location: /api/games/6` |
| `X-Total-Count` | convention : total d'une collection paginée | `X-Total-Count: 42` (`res.set('X-Total-Count', String(total))`) |
| `Authorization` | jeton du client (J2) | `Authorization: Bearer eyJhbGciOi…` |

## Nommage REST

- Des **noms au pluriel**, en minuscules : `/api/games`, `/api/games/3`. La **méthode** est le verbe : jamais `/getGames` ni `/games/delete?id=3`.
- L'identifiant dans le chemin ; filtres, tri et pagination dans la query : `/api/games?genre=fps&page=2`.
- Une sous-ressource ou une action courte est acceptable : `/api/teams/1/versus/2` (GET, rien n'est enregistré), `/api/matches/3/play` (POST, l'état change).

## curl et jq

| Option | Effet |
|---|---|
| `-i` | affiche statut et en-têtes (**toujours**) |
| `-s` | silencieux ; indispensable avant `\| jq` |
| `-X PATCH` | méthode (inutile pour GET ; POST implicite avec `-d`) |
| `-H 'Content-Type: application/json'` | ajoute un en-tête (répétable) |
| `-d '{"name": "x"}'` / `-d @game.json` | corps littéral / lu dans un fichier |
| `-o /dev/null -w '%{http_code}\n'` | n'affiche que le code |
| `\| jq` · `\| jq '.[].name'` · `\| jq '.errors'` · `\| jq length` | met en forme / extrait (`sudo apt install jq`) |

```bash
API=http://localhost:8000
curl -s $API/api/games | jq '.[].name'
curl -s "$API/api/games?genre=fps" | jq length
curl -i -X POST $API/api/games -H 'Content-Type: application/json' -d '{"name": "Test Game", "genre": "fps", "teamSize": 5}'
curl -i -X POST $API/api/games -H 'Content-Type: application/json' -d '{"name": "", "genre": "fps", "teamSize": 42}'   # 422
curl -i -X POST $API/api/games -d 'name=Oops'                                                                           # 415
curl -i -X PATCH $API/api/games/6 -H 'Content-Type: application/json' -d '{"teamSize": 2}'
curl -i -X DELETE $API/api/games/6                                                                                      # 204
curl -s -o /dev/null -w '%{http_code}\n' $API/api/games/999999                                                          # 404
```
> Windows : WSL ou Git Bash. Dans PowerShell, `curl` n'est pas curl (tapez `curl.exe`) et les guillemets sont piégeux : `-d @fichier.json`.

## Lire un test Hurl

Un fichier `.hurl` est une suite d'**entrées** : une requête, puis la réponse attendue. Hurl envoie, compare, passe à la suivante ; à la première assertion fausse, le fichier est en échec et Hurl montre la ligne fautive, la valeur attendue et la valeur reçue.

```hurl
# Une entrée = une requête + la réponse attendue
POST {{host}}/api/games                       # ① la requête : méthode, URL ({{host}} est une variable), en-têtes, corps
Content-Type: application/json
{
  "name": "Test Game Alpha",
  "genre": "sports",
  "teamSize": 3,
  "id": 424242
}
HTTP 201                                      # ② le statut attendu (sinon : échec immédiat)
[Captures]                                    # ③ on mémorise une valeur de la réponse pour la suite
game_url: header "Location"
game_id: jsonpath "$.id"
[Asserts]                                     # ④ chaque ligne doit être vraie
header "Location" matches "^/api/games/\\d+$"
header "Content-Type" contains "application/json"
jsonpath "$.teamSize" == 3
jsonpath "$.id" != 424242                     # l'id est choisi par la base, jamais par le client

GET {{host}}{{game_url}}                      # entrée suivante : la variable capturée est réutilisée
HTTP 200
[Asserts]
jsonpath "$.id" == {{game_id}}

GET {{host}}/api/games?genre=sports
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$[*].name" contains "Test Game Alpha"
jsonpath "$[*].genre" not contains "fps"

DELETE {{host}}{{game_url}}
HTTP 204
[Asserts]
bytes count == 0
```

- Prédicats : `==`, `!=`, `<=`, `contains`, `not contains`, `matches` (regex), `exists`, `not exists`, `isInteger`, `isString`, `isCollection`, `count`.
- `jsonpath "$.team.tag"` descend dans le JSON ; `$[0]` premier élément ; `$[*].nickname` tous les pseudos ; `$.errors[*].path` les champs en erreur.
- Un corps qui n'est pas du JSON (tests 415 et 400) s'écrit entre triple backticks.
- Les tests tournent sur `api-test`, une copie de l'API sur une base **vide** (`app_test`, sans données de démo) : chaque fichier crée ses propres données et compte derrière un filtre.

| Commande | Effet |
|---|---|
| `make test` | tous les fichiers de `tests/`, dans l'ordre |
| `make test f=02` | seulement `02-players.hurl` (préfixe du nom de fichier) |
| `make test ERRORS=long` | en échec, affiche la réponse HTTP complète (corps compris) |
| `make test f=04 ERRORS=long` | les deux |

En échec, lisez `--> tests/02-players.hurl:42:6` (fichier, ligne), puis `actual value is <…>` / `expected …`. L'en-tête de chaque fichier dit l'étape, les routes attendues et la forme des réponses.
