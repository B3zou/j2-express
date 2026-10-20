# ─────────────────────────────────────────────────────────────────────────────
# J1, repris au J2 · TD étape 4 — Player et la relation avec Team
# Attendu : GET/POST /api/players, GET/PATCH/DELETE /api/players/{id}
#           Entrée : nickname 2-30, country, role?, rating? (0-3000, défaut 1000), birthDate? (≥ 13 ans), teamId?
#           Sortie : { id, nickname, country, role, rating, team: { id, name, tag } | null } — jamais birthDate
#           Côté équipe : GET /api/teams/{id} renvoie players: [{ id, nickname, role, rating }], triés par pseudo
# ─────────────────────────────────────────────────────────────────────────────

# ── J2 : ce fichier s'authentifie (les écritures exigent un jeton depuis l'étape 4 du TD JWT).
#    Tant que POST /api/auth/login n'existe pas, il est rouge : c'est normal, il revient au vert à l'étape 2.
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t02@test.dev", "password": "password-02" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t02@test.dev", "password": "password-02" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"


POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "name": "Test Kernel Panic",
  "tag": "TKP",
  "country": "FR"
}
HTTP 201
[Captures]
team_id: jsonpath "$.id"
team_url: header "Location"

# L'équipe est désignée par son identifiant : teamId
POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "nickname": "Test_Zer0Day",
  "country": "FR",
  "role": "striker",
  "rating": 1850,
  "birthDate": "2002-04-12",
  "teamId": {{team_id}}
}
HTTP 201
[Captures]
player_url: header "Location"
player_id: jsonpath "$.id"
[Asserts]
header "Location" matches "^/api/players/\\d+$"
jsonpath "$.id" isInteger
jsonpath "$.nickname" == "Test_Zer0Day"
jsonpath "$.rating" == 1850
# L'équipe est renvoyée IMBRIQUÉE, réduite à id, name et tag
jsonpath "$.team.id" == {{team_id}}
jsonpath "$.team.name" == "Test Kernel Panic"
jsonpath "$.team.tag" == "TKP"
jsonpath "$.team.country" not exists
jsonpath "$.teamId" not exists
# Donnée personnelle : acceptée en écriture, jamais renvoyée
jsonpath "$.birthDate" not exists

GET {{host}}{{player_url}}
HTTP 200
[Asserts]
jsonpath "$.birthDate" not exists
jsonpath "$.team.tag" == "TKP"

# Côté équipe, les joueurs apparaissent (id, pseudo, rôle, classement), sans leur équipe
GET {{host}}{{team_url}}
HTTP 200
[Asserts]
jsonpath "$.players" count == 1
jsonpath "$.players[0].id" == {{player_id}}
jsonpath "$.players[0].nickname" == "Test_Zer0Day"
jsonpath "$.players[0].role" == "striker"
jsonpath "$.players[0].rating" == 1850
jsonpath "$.players[0].team" not exists

# Valeur par défaut du classement : 1000 ; rôle absent → null
POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "nickname": "Test_Mutex",
  "country": "BE",
  "teamId": {{team_id}}
}
HTTP 201
[Asserts]
jsonpath "$.rating" == 1000
jsonpath "$.role" == null

# Agent libre : pas d'équipe
POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "nickname": "Test_FreeAgent",
  "country": "CA",
  "rating": 2100
}
HTTP 201
[Asserts]
jsonpath "$.team" == null

# Équipe inexistante → 422 sur le champ « teamId » (la clé étrangère refuse)
POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "nickname": "Test_Ghost",
  "country": "FR",
  "teamId": 999999
}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "teamId"

# Mauvais type → 422
POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "nickname": "Test_Typo",
  "country": "FR",
  "rating": "beaucoup"
}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "rating"

# Règles : classement 0..3000, au moins 13 ans
POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "nickname": "Test_Kid",
  "country": "FR",
  "rating": 5000,
  "birthDate": "2020-01-01"
}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "rating"
jsonpath "$.errors[*].path" contains "birthDate"

# Une date est une date (AAAA-MM-JJ)
POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "nickname": "Test_Date",
  "country": "FR",
  "birthDate": "hier"
}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "birthDate"

# Champs obligatoires
POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "nickname"
jsonpath "$.errors[*].path" contains "country"

# Pseudo unique → 409
POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "nickname": "Test_Zer0Day",
  "country": "FR"
}
HTTP 409
[Asserts]
jsonpath "$.errors[0].path" == "nickname"

# Mise à jour partielle : l'équipe reste
PATCH {{host}}{{player_url}}
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "role": "playmaker",
  "rating": 1900
}
HTTP 200
[Asserts]
jsonpath "$.role" == "playmaker"
jsonpath "$.rating" == 1900
jsonpath "$.team.tag" == "TKP"

# Quitter l'équipe : teamId null
PATCH {{host}}{{player_url}}
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "teamId": null
}
HTTP 200
[Asserts]
jsonpath "$.team" == null

GET {{host}}{{team_url}}
HTTP 200
[Asserts]
jsonpath "$.players" count == 1
jsonpath "$.players[0].nickname" == "Test_Mutex"

# … et revenir : les joueurs de l'équipe sont triés par pseudo
PATCH {{host}}{{player_url}}
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "teamId": {{team_id}}
}
HTTP 200
[Asserts]
jsonpath "$.team.id" == {{team_id}}

GET {{host}}{{team_url}}
HTTP 200
[Asserts]
jsonpath "$.players" count == 2
jsonpath "$.players[0].nickname" == "Test_Mutex"
jsonpath "$.players[1].nickname" == "Test_Zer0Day"

PATCH {{host}}{{player_url}}
Authorization: Bearer {{token}}
Content-Type: application/json
{
  "teamId": 999999
}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "teamId"

# Erreurs en JSON
GET {{host}}/api/players/999999
HTTP 404
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.title" == "Player not found"

GET {{host}}/api/players/abc
HTTP 404

# Supprimer l'équipe : ses joueurs deviennent agents libres (ON DELETE SET NULL)
DELETE {{host}}{{team_url}}
Authorization: Bearer {{token}}
HTTP 204

GET {{host}}{{player_url}}
HTTP 200
[Asserts]
jsonpath "$.team" == null

# Suppression du joueur
DELETE {{host}}{{player_url}}
Authorization: Bearer {{token}}
HTTP 204

GET {{host}}{{player_url}}
HTTP 404
