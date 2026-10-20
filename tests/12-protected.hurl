# ─────────────────────────────────────────────────────────────────────────────
# J2 · TD JWT étapes 3 et 4 — requireAuth : GET /api/auth/me, puis toutes les écritures
# Attendu : sans jeton, jeton mal formé, invalide ou expiré → 401 + WWW-Authenticate: Bearer
#           avec un jeton valide → la route répond normalement ; les lectures restent publiques
#           Les 12 écritures (POST/PATCH/DELETE sur games, teams, players, matches, et …/play) sont protégées.
# ─────────────────────────────────────────────────────────────────────────────

# Trois jetons fabriqués à la main avec jsonwebtoken (voir docs/cheatsheets/jwt-bcrypt.md) :
#   expired : signé avec test-secret, exp = 2020-01-01   → « Token expired »
#   wrong   : signé avec un AUTRE secret (wrong-secret)  → « Invalid token »
GET {{host}}/api/health
[Options]
variable: expired=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwiZW1haWwiOiJleHBpcmVkQHRlc3QuZGV2IiwiaWF0IjoxNTc3ODMzMjAwLCJleHAiOjE1Nzc4MzY4MDB9.HXcltaaycnUVAocNMtFsviFVjj3I4A1sQBu9WHUMWjg
variable: wrong=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwiZW1haWwiOiJ3cm9uZ0B0ZXN0LmRldiIsImlhdCI6MTc5MjUxOTQ2MiwiZXhwIjo0OTQ4Mjc5NDYyfQ.Ig9_aI28_E4wzQ6fDoNvZcAaagkeej1i520LKnLeL-8
HTTP 200

POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t12@test.dev", "password": "password-12" }
HTTP 201
[Captures]
user_id: jsonpath "$.id"

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t12@test.dev", "password": "password-12" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"

# ── Étape 3 : GET /api/auth/me ───────────────────────────────────────────────

# Sans en-tête → 401 Unauthorized, et l'API dit comment s'authentifier
GET {{host}}/api/auth/me
HTTP 401
[Asserts]
header "WWW-Authenticate" == "Bearer"
header "Content-Type" contains "application/json"
jsonpath "$.title" == "Unauthorized"
jsonpath "$.status" == 401

# « Bearer » sans jeton derrière → 401 (pas de plantage dans jwt.verify)
GET {{host}}/api/auth/me
Authorization: Bearer 
HTTP 401
[Asserts]
jsonpath "$.title" == "Unauthorized"

# Un autre schéma (Basic) → 401 : on n'accepte que Bearer
GET {{host}}/api/auth/me
Authorization: Basic dDEyQHRlc3QuZGV2OnBhc3N3b3JkLTEy
HTTP 401
[Asserts]
jsonpath "$.title" == "Unauthorized"

# N'importe quoi → 401 Invalid token
GET {{host}}/api/auth/me
Authorization: Bearer ceci.nest.pas-un-jwt
HTTP 401
[Asserts]
header "WWW-Authenticate" == "Bearer"
jsonpath "$.title" == "Invalid token"

# Signé avec un autre secret → 401 Invalid token (la signature ne correspond pas)
GET {{host}}/api/auth/me
Authorization: Bearer {{wrong}}
HTTP 401
[Asserts]
jsonpath "$.title" == "Invalid token"

# Expiré → 401 Token expired
GET {{host}}/api/auth/me
Authorization: Bearer {{expired}}
HTTP 401
[Asserts]
jsonpath "$.title" == "Token expired"

# Avec le bon jeton → qui je suis, lu dans le jeton
GET {{host}}/api/auth/me
Authorization: Bearer {{token}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{user_id}}
jsonpath "$.email" == "t12@test.dev"
jsonpath "$.password" not exists

# ── Étape 4 : les lectures restent publiques ─────────────────────────────────

GET {{host}}/api/games
HTTP 200

GET {{host}}/api/teams?country=ZZ
HTTP 200

GET {{host}}/api/players?limit=2
HTTP 200

GET {{host}}/api/players/top?limit=7
HTTP 200

GET {{host}}/api/matches
HTTP 200

# ── Étape 4 : les 12 écritures exigent un jeton (corps valides : c'est bien le jeton qui manque) ──

POST {{host}}/api/games
Content-Type: application/json
{ "name": "Test Protected Game", "genre": "fps", "teamSize": 5 }
HTTP 401
[Asserts]
header "WWW-Authenticate" == "Bearer"
jsonpath "$.title" == "Unauthorized"

PATCH {{host}}/api/games/1
Content-Type: application/json
{ "teamSize": 4 }
HTTP 401

DELETE {{host}}/api/games/1
HTTP 401

POST {{host}}/api/teams
Content-Type: application/json
{ "name": "Test Protected Team", "tag": "TPT", "country": "FR" }
HTTP 401

PATCH {{host}}/api/teams/1
Content-Type: application/json
{ "name": "Renamed" }
HTTP 401

DELETE {{host}}/api/teams/1
HTTP 401

POST {{host}}/api/players
Content-Type: application/json
{ "nickname": "Protected_One", "country": "FR" }
HTTP 401

PATCH {{host}}/api/players/1
Content-Type: application/json
{ "rating": 1500 }
HTTP 401

DELETE {{host}}/api/players/1
HTTP 401

POST {{host}}/api/matches
Content-Type: application/json
{ "teamAId": 1, "teamBId": 2 }
HTTP 401

POST {{host}}/api/matches/1/play
HTTP 401

DELETE {{host}}/api/matches/1
HTTP 401

# Un jeton expiré ne vaut pas mieux qu'aucun jeton
POST {{host}}/api/teams
Content-Type: application/json
Authorization: Bearer {{expired}}
{ "name": "Test Protected Team", "tag": "TPT", "country": "FR" }
HTTP 401
[Asserts]
jsonpath "$.title" == "Token expired"

# ── Avec le jeton : tout fonctionne comme hier ───────────────────────────────

POST {{host}}/api/games
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "Test Protected Game", "genre": "fps", "teamSize": 5 }
HTTP 201
[Captures]
game_url: header "Location"

PATCH {{host}}{{game_url}}
Content-Type: application/json
Authorization: Bearer {{token}}
{ "teamSize": 4 }
HTTP 200
[Asserts]
jsonpath "$.teamSize" == 4

# Jeton valide mais corps invalide → 422 : requireAuth passe avant validate, et validate fait son travail
POST {{host}}/api/games
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "", "genre": "fps", "teamSize": 42 }
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "name"

DELETE {{host}}{{game_url}}
Authorization: Bearer {{token}}
HTTP 204

POST {{host}}/api/teams
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "Test Protected Team", "tag": "TPT", "country": "FR" }
HTTP 201
[Captures]
team_url: header "Location"
team_id: jsonpath "$.id"

POST {{host}}/api/teams
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "Test Protected Rival", "tag": "TPR", "country": "DE" }
HTTP 201
[Captures]
rival_id: jsonpath "$.id"

PATCH {{host}}{{team_url}}
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "Test Protected Team 2" }
HTTP 200

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Protected_One", "country": "FR", "rating": 2000, "teamId": {{team_id}} }
HTTP 201
[Captures]
player_url: header "Location"

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Protected_Two", "country": "DE", "rating": 1800, "teamId": {{rival_id}} }
HTTP 201

PATCH {{host}}{{player_url}}
Content-Type: application/json
Authorization: Bearer {{token}}
{ "rating": 2100 }
HTTP 200
[Asserts]
jsonpath "$.rating" == 2100

POST {{host}}/api/matches
Content-Type: application/json
Authorization: Bearer {{token}}
{ "teamAId": {{team_id}}, "teamBId": {{rival_id}} }
HTTP 201
[Captures]
match_url: header "Location"

POST {{host}}{{match_url}}/play?seed=42
Authorization: Bearer {{token}}
HTTP 200
[Asserts]
jsonpath "$.status" == "played"

DELETE {{host}}{{match_url}}
Authorization: Bearer {{token}}
HTTP 204

DELETE {{host}}{{player_url}}
Authorization: Bearer {{token}}
HTTP 204

DELETE {{host}}{{team_url}}
Authorization: Bearer {{token}}
HTTP 204

# La lecture d'un versus reste publique (les deux équipes existent encore ? non : 404, mais pas 401)
GET {{host}}/api/teams/{{team_id}}/versus/{{rival_id}}
HTTP 404
