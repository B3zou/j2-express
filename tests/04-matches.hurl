# ─────────────────────────────────────────────────────────────────────────────
# J1, repris au J2 · TP partie 1 — Match : une ressource neuve, avec ses règles et une action
# Attendu : POST /api/matches { teamAId, teamBId } → 201, status "scheduled"
#           GET /api/matches[?status=scheduled|played], GET /api/matches/{id}, DELETE /api/matches/{id}
#           POST /api/matches/{id}/play[?seed=] → 200 : le match est joué (score, winner, playedAt) ;
#             409 s'il l'est déjà, 422 si une équipe n'a aucun joueur
#           Sortie : { id, status, teamA: { id, name, tag }, teamB, score: [a, b] | null, winner: tag | null, playedAt | null }
# ─────────────────────────────────────────────────────────────────────────────

# ── J2 : ce fichier s'authentifie (les écritures exigent un jeton depuis l'étape 4 du TD JWT).
#    Tant que POST /api/auth/login n'existe pas, il est rouge : c'est normal, il revient au vert à l'étape 2.
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t04@test.dev", "password": "password-04" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t04@test.dev", "password": "password-04" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"


POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{ "name": "Match Alpha", "tag": "MTA", "country": "FR" }
HTTP 201
[Captures]
mta_id: jsonpath "$.id"

POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{ "name": "Match Beta", "tag": "MTB", "country": "DE" }
HTTP 201
[Captures]
mtb_id: jsonpath "$.id"

POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{ "name": "Match Empty", "tag": "MTE", "country": "IT" }
HTTP 201
[Captures]
mte_id: jsonpath "$.id"

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "M_One", "country": "FR", "rating": 2000, "teamId": {{mta_id}} }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "M_Two", "country": "FR", "rating": 1800, "teamId": {{mta_id}} }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "M_Three", "country": "DE", "rating": 1500, "teamId": {{mtb_id}} }
HTTP 201

# Programmer un match
POST {{host}}/api/matches
Authorization: Bearer {{token}}
Content-Type: application/json
{ "teamAId": {{mta_id}}, "teamBId": {{mtb_id}} }
HTTP 201
[Captures]
match_url: header "Location"
match_id: jsonpath "$.id"
[Asserts]
header "Location" matches "^/api/matches/\\d+$"
jsonpath "$.id" isInteger
jsonpath "$.status" == "scheduled"
jsonpath "$.teamA.id" == {{mta_id}}
jsonpath "$.teamA.name" == "Match Alpha"
jsonpath "$.teamA.tag" == "MTA"
jsonpath "$.teamB.tag" == "MTB"
jsonpath "$.score" == null
jsonpath "$.winner" == null
jsonpath "$.playedAt" == null
jsonpath "$.teamAId" not exists

# Une équipe ne joue pas contre elle-même
POST {{host}}/api/matches
Authorization: Bearer {{token}}
Content-Type: application/json
{ "teamAId": {{mta_id}}, "teamBId": {{mta_id}} }
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "teamBId"

# Équipe inconnue → 422 sur le champ en cause
POST {{host}}/api/matches
Authorization: Bearer {{token}}
Content-Type: application/json
{ "teamAId": 999999, "teamBId": {{mtb_id}} }
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "teamAId"

POST {{host}}/api/matches
Authorization: Bearer {{token}}
Content-Type: application/json
{ "teamAId": {{mta_id}}, "teamBId": 999999 }
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "teamBId"

POST {{host}}/api/matches
Authorization: Bearer {{token}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "teamAId"
jsonpath "$.errors[*].path" contains "teamBId"

POST {{host}}/api/matches
Authorization: Bearer {{token}}
Content-Type: application/json
{ "teamAId": "un", "teamBId": {{mtb_id}} }
HTTP 422

# Un id hors des bornes de PostgreSQL (integer) : 422, pas 500
POST {{host}}/api/matches
Authorization: Bearer {{token}}
Content-Type: application/json
{ "teamAId": 99999999999, "teamBId": {{mtb_id}} }
HTTP 422

# Jouer un match se fait sans corps : Swagger UI et les navigateurs envoient alors Content-Length: 0,
# ce n'est pas un 415 (match inexistant ici → 404)
POST {{host}}/api/matches/999999/play
Authorization: Bearer {{token}}
Content-Length: 0
HTTP 404

# Deux autres matchs : une revanche, et un match contre une équipe sans joueur
POST {{host}}/api/matches
Authorization: Bearer {{token}}
Content-Type: application/json
{ "teamAId": {{mta_id}}, "teamBId": {{mtb_id}} }
HTTP 201
[Captures]
match2_url: header "Location"

POST {{host}}/api/matches
Authorization: Bearer {{token}}
Content-Type: application/json
{ "teamAId": {{mta_id}}, "teamBId": {{mte_id}} }
HTTP 201
[Captures]
match3_url: header "Location"

# La liste et son filtre
GET {{host}}/api/matches
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count == 3

GET {{host}}/api/matches?status=played
HTTP 200
[Asserts]
jsonpath "$" count == 0

GET {{host}}/api/matches?status=scheduled
HTTP 200
[Asserts]
jsonpath "$" count == 3

GET {{host}}/api/matches?status=annule
HTTP 400

GET {{host}}{{match_url}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{match_id}}
jsonpath "$.status" == "scheduled"

# Jouer le match : le résultat est enregistré
POST {{host}}{{match_url}}/play?seed=42
Authorization: Bearer {{token}}
HTTP 200
[Captures]
winner1: jsonpath "$.winner"
score1: jsonpath "$.score[0]"
[Asserts]
jsonpath "$.status" == "played"
jsonpath "$.score" count == 2
jsonpath "$.score" contains 3
jsonpath "$.score[0]" <= 3
jsonpath "$.score[1]" <= 3
jsonpath "$.winner" matches "^(MTA|MTB)$"
jsonpath "$.playedAt" isString

GET {{host}}{{match_url}}
HTTP 200
[Asserts]
jsonpath "$.status" == "played"
jsonpath "$.winner" == "{{winner1}}"
jsonpath "$.score[0]" == {{score1}}

# Un match ne se joue qu'une fois → 409, et rien ne change
POST {{host}}{{match_url}}/play
Authorization: Bearer {{token}}
HTTP 409
[Asserts]
jsonpath "$.status" == 409

GET {{host}}{{match_url}}
HTTP 200
[Asserts]
jsonpath "$.winner" == "{{winner1}}"
jsonpath "$.score[0]" == {{score1}}

# Même graine, mêmes équipes : même résultat
POST {{host}}{{match2_url}}/play?seed=42
Authorization: Bearer {{token}}
HTTP 200
[Asserts]
jsonpath "$.winner" == "{{winner1}}"
jsonpath "$.score[0]" == {{score1}}

GET {{host}}/api/matches?status=played
HTTP 200
[Asserts]
jsonpath "$" count == 2

GET {{host}}/api/matches?status=scheduled
HTTP 200
[Asserts]
jsonpath "$" count == 1

# Une équipe sans joueur n'a pas de niveau : impossible de jouer
POST {{host}}{{match3_url}}/play
Authorization: Bearer {{token}}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "teamBId"

GET {{host}}{{match3_url}}
HTTP 200
[Asserts]
jsonpath "$.status" == "scheduled"

# Paramètre et identifiants invalides
POST {{host}}{{match3_url}}/play?seed=abc
Authorization: Bearer {{token}}
HTTP 400

POST {{host}}/api/matches/999999/play
Authorization: Bearer {{token}}
HTTP 404
[Asserts]
header "Content-Type" contains "application/json"

GET {{host}}/api/matches/abc
HTTP 404

# Suppression
DELETE {{host}}{{match3_url}}
Authorization: Bearer {{token}}
HTTP 204

GET {{host}}{{match3_url}}
HTTP 404
