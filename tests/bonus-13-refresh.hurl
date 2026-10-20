# ─────────────────────────────────────────────────────────────────────────────
# J2 · Bonus 13 — Refresh token : un jeton d'accès court, un jeton de rafraîchissement long et révocable
# Attendu : POST /api/auth/login renvoie aussi refreshToken (64 caractères hexadécimaux)
#           POST /api/auth/refresh { refreshToken } → 200 un NOUVEAU couple ; l'ancien refreshToken ne vaut plus rien (401)
#           POST /api/auth/logout  { refreshToken } → 204 ; un refresh ensuite → 401
#           Lancer : make test f=13
# ─────────────────────────────────────────────────────────────────────────────

POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t13@test.dev", "password": "password-13" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t13@test.dev", "password": "password-13" }
HTTP 200
[Captures]
access1: jsonpath "$.accessToken"
refresh1: jsonpath "$.refreshToken"
[Asserts]
jsonpath "$.refreshToken" matches "^[0-9a-f]{64}$"
jsonpath "$.accessToken" matches "^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$"

# Rafraîchir : un nouveau couple (rotation)
POST {{host}}/api/auth/refresh
Content-Type: application/json
{ "refreshToken": "{{refresh1}}" }
HTTP 200
[Captures]
access2: jsonpath "$.accessToken"
refresh2: jsonpath "$.refreshToken"
[Asserts]
jsonpath "$.tokenType" == "Bearer"
jsonpath "$.refreshToken" matches "^[0-9a-f]{64}$"
jsonpath "$.refreshToken" != "{{refresh1}}"

# Le nouveau jeton d'accès fonctionne
GET {{host}}/api/auth/me
Authorization: Bearer {{access2}}
HTTP 200
[Asserts]
jsonpath "$.email" == "t13@test.dev"

# L'ancien refresh token a été consommé → 401
POST {{host}}/api/auth/refresh
Content-Type: application/json
{ "refreshToken": "{{refresh1}}" }
HTTP 401
[Asserts]
jsonpath "$.title" == "Invalid refresh token"

# Un refresh token inventé → 401, même forme
POST {{host}}/api/auth/refresh
Content-Type: application/json
{ "refreshToken": "0000000000000000000000000000000000000000000000000000000000000000" }
HTTP 401

# Corps invalide → 422
POST {{host}}/api/auth/refresh
Content-Type: application/json
{ }
HTTP 422

# Déconnexion : le refresh token courant est révoqué
POST {{host}}/api/auth/logout
Content-Type: application/json
{ "refreshToken": "{{refresh2}}" }
HTTP 204

POST {{host}}/api/auth/refresh
Content-Type: application/json
{ "refreshToken": "{{refresh2}}" }
HTTP 401

# Le jeton d'accès, lui, reste valable jusqu'à son expiration (stateless) : c'est le compromis du JWT
GET {{host}}/api/auth/me
Authorization: Bearer {{access2}}
HTTP 200
