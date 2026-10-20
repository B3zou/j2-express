# ─────────────────────────────────────────────────────────────────────────────
# J2 · Bonus 25 — Les refresh tokens dans Redis (nécessite le bonus 13)
# Même contrat HTTP que bonus-13 ; ce qui change est DERRIÈRE : plus de table refresh_token,
# une clé Redis « refresh:<sha256 du jeton> » → id utilisateur, avec une durée de vie (EX 7 jours).
# Vérifiez avec make redis-cli : KEYS refresh:*  puis  TTL refresh:<…>
# Lancer : make test f=25
# ─────────────────────────────────────────────────────────────────────────────

POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t25@test.dev", "password": "password-25" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t25@test.dev", "password": "password-25" }
HTTP 200
[Captures]
refresh1: jsonpath "$.refreshToken"
[Asserts]
jsonpath "$.refreshToken" matches "^[0-9a-f]{64}$"

POST {{host}}/api/auth/refresh
Content-Type: application/json
{ "refreshToken": "{{refresh1}}" }
HTTP 200
[Captures]
access2: jsonpath "$.accessToken"
refresh2: jsonpath "$.refreshToken"
[Asserts]
jsonpath "$.refreshToken" != "{{refresh1}}"

GET {{host}}/api/auth/me
Authorization: Bearer {{access2}}
HTTP 200
[Asserts]
jsonpath "$.email" == "t25@test.dev"

# Rotation : l'ancien ne vaut plus rien
POST {{host}}/api/auth/refresh
Content-Type: application/json
{ "refreshToken": "{{refresh1}}" }
HTTP 401
[Asserts]
jsonpath "$.title" == "Invalid refresh token"

POST {{host}}/api/auth/logout
Content-Type: application/json
{ "refreshToken": "{{refresh2}}" }
HTTP 204

POST {{host}}/api/auth/refresh
Content-Type: application/json
{ "refreshToken": "{{refresh2}}" }
HTTP 401
