# ─────────────────────────────────────────────────────────────────────────────
# J2 · TD Redis étape 2 — Le middleware cached(ttl) sur trois routes
# Attendu : GET /api/players/top (60 s), GET /api/teams/{id}/versus/{opponentId} (60 s), GET /api/teams (30 s)
#           → MISS puis HIT ; la query est triée (country=IS&limit=3 ≡ limit=3&country=IS) ;
#           GET /api/teams/{id} n'est PAS caché (pas d'en-tête) ; un 404 n'est jamais mis en cache
# ─────────────────────────────────────────────────────────────────────────────

POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t21@test.dev", "password": "password-21" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t21@test.dev", "password": "password-21" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"

POST {{host}}/api/teams
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "Cache Alpha", "tag": "CCA", "country": "CC" }
HTTP 201
[Captures]
alpha_id: jsonpath "$.id"

POST {{host}}/api/teams
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "Cache Beta", "tag": "CCB", "country": "CC" }
HTTP 201
[Captures]
beta_id: jsonpath "$.id"

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Cache_Golf", "country": "IS", "rating": 2000, "teamId": {{alpha_id}} }
HTTP 201

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Cache_Hotel", "country": "IS", "rating": 1800, "teamId": {{beta_id}} }
HTTP 201

# ── /api/teams : MISS puis HIT (un filtre propre à ce fichier : les autres tests ne partagent pas la clé) ──
GET {{host}}/api/teams?country=CC
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$[*].tag" contains "CCA"

GET {{host}}/api/teams?country=CC
HTTP 200
[Asserts]
header "X-Cache" == "HIT"
jsonpath "$[*].tag" contains "CCA"

# ── /versus : MISS puis HIT, même résultat (la graine fait partie de la query, donc de la clé) ──
GET {{host}}/api/teams/{{alpha_id}}/versus/{{beta_id}}?seed=7
HTTP 200
[Captures]
winner: jsonpath "$.winner"
[Asserts]
header "X-Cache" == "MISS"

GET {{host}}/api/teams/{{alpha_id}}/versus/{{beta_id}}?seed=7
HTTP 200
[Asserts]
header "X-Cache" == "HIT"
jsonpath "$.winner" == "{{winner}}"

# ── /players/top : l'ordre des paramètres ne change pas la clé ──
GET {{host}}/api/players/top?country=IS&limit=2
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$" count == 2

GET {{host}}/api/players/top?limit=2&country=IS
HTTP 200
[Asserts]
header "X-Cache" == "HIT"
jsonpath "$" count == 2

# ── GET /api/teams/{id} : pas de cache ici (on a choisi : lecture peu coûteuse, fraîcheur attendue) ──
GET {{host}}/api/teams/{{alpha_id}}
HTTP 200
[Asserts]
header "X-Cache" not exists

# ── Un 404 n'est jamais mis en cache : deux fois 404, jamais HIT ──
GET {{host}}/api/teams/999999/versus/{{beta_id}}
HTTP 404
[Asserts]
header "X-Cache" != "HIT"

GET {{host}}/api/teams/999999/versus/{{beta_id}}
HTTP 404
[Asserts]
header "X-Cache" != "HIT"
jsonpath "$.title" == "Team not found"

# Un 400 non plus (validateQuery avant cached)
GET {{host}}/api/teams/{{alpha_id}}/versus/{{beta_id}}?seed=abc
HTTP 400
[Asserts]
header "X-Cache" not exists
