# ─────────────────────────────────────────────────────────────────────────────
# J2 · Bonus 24 — Rate limiting sur POST /api/auth/login, avec Redis (INCR + EXPIRE)
# Attendu : 5 tentatives par minute pour un couple (adresse IP, email) ; la 6e → 429 Too Many Requests
#           + en-tête Retry-After (en secondes) ; même avec le bon mot de passe, tant que la fenêtre dure
#           Lancer : make test f=24
# ─────────────────────────────────────────────────────────────────────────────

POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t24@test.dev", "password": "password-24" }
HTTP 201

# 5 échecs → 5 × 401
POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t24@test.dev", "password": "wrong-password-1" }
HTTP 401

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t24@test.dev", "password": "wrong-password-2" }
HTTP 401

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t24@test.dev", "password": "wrong-password-3" }
HTTP 401

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t24@test.dev", "password": "wrong-password-4" }
HTTP 401

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t24@test.dev", "password": "wrong-password-5" }
HTTP 401

# La 6e tentative est bloquée, bon mot de passe ou pas
POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t24@test.dev", "password": "password-24" }
HTTP 429
[Asserts]
header "Retry-After" matches "^[1-9][0-9]?$"
header "Content-Type" contains "application/json"
jsonpath "$.title" == "Too Many Requests"
jsonpath "$.status" == 429

# Un autre compte n'est pas affecté (la clé contient l'email)
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t24b@test.dev", "password": "password-24" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t24b@test.dev", "password": "password-24" }
HTTP 200
