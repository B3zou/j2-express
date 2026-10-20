# ─────────────────────────────────────────────────────────────────────────────
# J1, repris au J2 · TD étapes 2 et 3 — Team : lecture, puis écriture et filtre
# Attendu : GET/POST /api/teams, GET/PATCH/DELETE /api/teams/{id}, filtre ?country=
#           Règles : name 2-50, tag /^[A-Z0-9]{2,5}$/, country /^[A-Z]{2}$/, name et tag uniques (409)
# ─────────────────────────────────────────────────────────────────────────────

# ── J2 : ce fichier s'authentifie (les écritures exigent un jeton depuis l'étape 4 du TD JWT).
#    Tant que POST /api/auth/login n'existe pas, il est rouge : c'est normal, il revient au vert à l'étape 2.
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t01@test.dev", "password": "password-01" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t01@test.dev", "password": "password-01" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"


POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "name": "Test Null Pointers",
  "tag": "TNP",
  "country": "FR"
}
HTTP 201
[Captures]
team_url: header "Location"
team_id: jsonpath "$.id"
[Asserts]
header "Location" matches "^/api/teams/\\d+$"
jsonpath "$.id" isInteger
jsonpath "$.name" == "Test Null Pointers"
jsonpath "$.tag" == "TNP"
jsonpath "$.country" == "FR"

GET {{host}}{{team_url}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{team_id}}
jsonpath "$.tag" == "TNP"

# Le tag doit respecter /^[A-Z0-9]{2,5}$/
POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "name": "Test Bad Tag",
  "tag": "bad!",
  "country": "FR"
}
HTTP 422
[Asserts]
jsonpath "$.title" == "Validation Failed"
jsonpath "$.errors[*].path" contains "tag"

# … en majuscules, donc
POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "name": "Test Lower Tag",
  "tag": "tnp",
  "country": "FR"
}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "tag"

# Le pays est un code à deux lettres majuscules (ISO 3166-1 alpha-2)
POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "name": "Test Bad Country",
  "tag": "TBC",
  "country": "France"
}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "country"

# Le nom fait au moins 2 caractères
POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "name": "A",
  "tag": "TAB",
  "country": "FR"
}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "name"

# Champs obligatoires
POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "name"
jsonpath "$.errors[*].path" contains "tag"
jsonpath "$.errors[*].path" contains "country"

# Nom unique → 409 Conflict (contrainte UNIQUE de PostgreSQL)
POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "name": "Test Null Pointers",
  "tag": "TNQ",
  "country": "FR"
}
HTTP 409
[Asserts]
jsonpath "$.title" == "Conflict"
jsonpath "$.errors[0].path" == "name"

# Tag unique → 409
POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "name": "Test Other Team",
  "tag": "TNP",
  "country": "BE"
}
HTTP 409
[Asserts]
jsonpath "$.errors[0].path" == "tag"

# Un id envoyé par le client est ignoré
POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "id": 424242,
  "name": "Test Lag Busters",
  "tag": "TLB",
  "country": "BE"
}
HTTP 201
[Captures]
team2_url: header "Location"
[Asserts]
jsonpath "$.id" != 424242

POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "name": "Test Async Await",
  "tag": "TAA",
  "country": "BE"
}
HTTP 201

# La liste : un tableau trié par nom, sans les joueurs (ils sont sur l'élément, pas sur la liste)
GET {{host}}/api/teams
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$[*].tag" contains "TNP"
jsonpath "$[0].players" not exists

# Filtre sur le pays + tri par nom
GET {{host}}/api/teams?country=BE
HTTP 200
[Asserts]
jsonpath "$" count == 2
jsonpath "$[0].tag" == "TAA"
jsonpath "$[1].tag" == "TLB"
jsonpath "$[*].tag" not contains "TNP"

# Le pays est accepté en minuscules
GET {{host}}/api/teams?country=be
HTTP 200
[Asserts]
jsonpath "$" count == 2

# Un pays invalide → 400 Bad Request (paramètre de requête)
GET {{host}}/api/teams?country=Belgique
HTTP 400

# Mise à jour partielle
PATCH {{host}}{{team2_url}}
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "country": "CH"
}
HTTP 200
[Asserts]
jsonpath "$.country" == "CH"
jsonpath "$.tag" == "TLB"

PATCH {{host}}{{team2_url}}
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "tag": "trop-long"
}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "tag"

PATCH {{host}}{{team2_url}}
Authorization: Bearer {{token}}
Content-Type: application/json
{}
HTTP 200
[Asserts]
jsonpath "$.tag" == "TLB"

# Erreurs en JSON
GET {{host}}/api/teams/999999
HTTP 404
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.title" == "Team not found"

GET {{host}}/api/teams/abc
HTTP 404

PATCH {{host}}/api/teams/999999
Authorization: Bearer {{token}}
Content-Type: application/json
{ "country": "FR" }
HTTP 404

# Suppression
DELETE {{host}}{{team2_url}}
Authorization: Bearer {{token}}
HTTP 204

GET {{host}}{{team2_url}}
HTTP 404

DELETE {{host}}{{team2_url}}
Authorization: Bearer {{token}}
HTTP 404
