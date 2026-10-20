# ─────────────────────────────────────────────────────────────────────────────
# J2 · TD JWT étape 2 — POST /api/auth/login : un jeton en échange d'un mot de passe
# Attendu : 200 { accessToken (un JWT), tokenType: "Bearer", expiresIn (secondes) }
#           401 « Invalid credentials » IDENTIQUE pour un email inconnu et pour un mot de passe faux
#           (on ne dit jamais à un attaquant lequel des deux est bon) ; 422 si le corps est invalide
# ─────────────────────────────────────────────────────────────────────────────

POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t11@test.dev", "password": "password-11" }
HTTP 201

# Bon mot de passe → un jeton
POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t11@test.dev", "password": "password-11" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"
[Asserts]
header "Content-Type" contains "application/json"
# Un JWT : trois segments base64url séparés par des points (collez-le sur https://jwt.io)
jsonpath "$.accessToken" matches "^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$"
jsonpath "$.tokenType" == "Bearer"
jsonpath "$.expiresIn" isInteger
jsonpath "$.expiresIn" > 0
# Rien d'autre : surtout pas le mot de passe, ni l'utilisateur complet
jsonpath "$.password" not exists
jsonpath "$.user.password" not exists

# L'email est normalisé comme à l'inscription : majuscules acceptées
POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "T11@TEST.dev", "password": "password-11" }
HTTP 200

# Mauvais mot de passe → 401, sans indice
POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t11@test.dev", "password": "password-xx" }
HTTP 401
[Asserts]
header "WWW-Authenticate" == "Bearer"
jsonpath "$.title" == "Invalid credentials"
jsonpath "$.status" == 401
jsonpath "$.errors" not exists

# Email inconnu → EXACTEMENT la même réponse
POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "nobody@test.dev", "password": "password-11" }
HTTP 401
[Asserts]
header "WWW-Authenticate" == "Bearer"
jsonpath "$.title" == "Invalid credentials"
jsonpath "$.status" == 401
jsonpath "$.errors" not exists

# Corps invalide → 422 (la validation passe avant la vérification du mot de passe)
POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t11@test.dev" }
HTTP 422
[Asserts]
jsonpath "$.errors[0].path" == "password"
