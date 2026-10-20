# ─────────────────────────────────────────────────────────────────────────────
# J2 · TD JWT étape 1 — POST /api/auth/register : un compte, un mot de passe HACHÉ
# Attendu : 201 { id, email, createdAt } — JAMAIS le mot de passe (ni en clair, ni haché) dans la réponse
#           email normalisé en minuscules ; 422 si invalide ; 409 si l'email existe déjà
# ─────────────────────────────────────────────────────────────────────────────

POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t10@test.dev", "password": "password-10" }
HTTP 201
[Captures]
user_id: jsonpath "$.id"
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.id" isInteger
jsonpath "$.email" == "t10@test.dev"
jsonpath "$.createdAt" isString
# Le mot de passe ne sort JAMAIS de l'API, même haché
jsonpath "$.password" not exists
jsonpath "$.passwordHash" not exists

# Le même email en majuscules : c'est le même compte → 409 (zod normalise en minuscules)
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "T10@Test.dev", "password": "another-password" }
HTTP 409
[Asserts]
jsonpath "$.title" == "Conflict"
jsonpath "$.errors[0].path" == "email"

# Validation → 422 : email invalide
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "pas-un-email", "password": "password-10" }
HTTP 422
[Asserts]
jsonpath "$.title" == "Validation Failed"
jsonpath "$.errors[*].path" contains "email"

# Mot de passe trop court (8 caractères minimum)
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t10b@test.dev", "password": "1234567" }
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "password"

# Champ manquant
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t10c@test.dev" }
HTTP 422
[Asserts]
jsonpath "$.errors[0].path" == "password"

# Sans JSON → 415 (requireJson, comme hier)
POST {{host}}/api/auth/register
Content-Type: text/plain
`email=t10d@test.dev`
HTTP 415
