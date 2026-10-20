# ─────────────────────────────────────────────────────────────────────────────
# J1, repris au J2 · TP partie 2 — Deux routes métier
# Attendu : GET /api/teams/{id}/versus/{opponentId}[?seed=42]
#             → un match simulé au meilleur des 5 manches (rien n'est enregistré), même forme qu'au J0
#           GET /api/players/top?limit=3&country=IS
#             → classement décroissant par rating, limit entre 1 et 50 (10 par défaut), 400 sinon
# ─────────────────────────────────────────────────────────────────────────────

# ── J2 : ce fichier s'authentifie (les écritures exigent un jeton depuis l'étape 4 du TD JWT).
#    Tant que POST /api/auth/login n'existe pas, il est rouge : c'est normal, il revient au vert à l'étape 2.
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t05@test.dev", "password": "password-05" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t05@test.dev", "password": "password-05" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"


POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{ "name": "Versus Alpha", "tag": "VSA", "country": "FR" }
HTTP 201
[Captures]
vsa_id: jsonpath "$.id"

POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{ "name": "Versus Beta", "tag": "VSB", "country": "DE" }
HTTP 201
[Captures]
vsb_id: jsonpath "$.id"

POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{ "name": "Versus Empty", "tag": "VSE", "country": "IT" }
HTTP 201
[Captures]
vse_id: jsonpath "$.id"

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Vs_One", "country": "FR", "rating": 2000, "teamId": {{vsa_id}} }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Vs_Two", "country": "FR", "rating": 1800, "teamId": {{vsa_id}} }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Vs_Three", "country": "DE", "rating": 1500, "teamId": {{vsb_id}} }
HTTP 201

# Un match : les deux équipes (avec leur niveau moyen), le score, le gagnant, le détail des manches
GET {{host}}/api/teams/{{vsa_id}}/versus/{{vsb_id}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.teamA.id" == {{vsa_id}}
jsonpath "$.teamA.tag" == "VSA"
jsonpath "$.teamA.name" == "Versus Alpha"
jsonpath "$.teamA.rating" == 1900
jsonpath "$.teamB.tag" == "VSB"
jsonpath "$.teamB.rating" == 1500
jsonpath "$.winner" matches "^(VSA|VSB)$"
jsonpath "$.score" count == 2
jsonpath "$.score" contains 3
jsonpath "$.score[0]" <= 3
jsonpath "$.score[1]" <= 3
jsonpath "$.rounds" count >= 3
jsonpath "$.rounds" count <= 5
jsonpath "$.rounds[0]" matches "^(VSA|VSB)$"

# Avec une graine (seed), le tirage est reproductible : deux appels, même résultat
GET {{host}}/api/teams/{{vsa_id}}/versus/{{vsb_id}}?seed=42
HTTP 200
[Captures]
winner1: jsonpath "$.winner"
rounds1: jsonpath "$.rounds" count

GET {{host}}/api/teams/{{vsa_id}}/versus/{{vsb_id}}?seed=42
HTTP 200
[Asserts]
jsonpath "$.winner" == "{{winner1}}"
jsonpath "$.rounds" count == {{rounds1}}

GET {{host}}/api/teams/{{vsa_id}}/versus/{{vsb_id}}?seed=abc
HTTP 400

# Une équipe ne joue pas contre elle-même
GET {{host}}/api/teams/{{vsa_id}}/versus/{{vsa_id}}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "opponentId"

# Une équipe sans joueur n'a pas de niveau : impossible de simuler
GET {{host}}/api/teams/{{vsa_id}}/versus/{{vse_id}}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "opponentId"

GET {{host}}/api/teams/{{vse_id}}/versus/{{vsa_id}}
HTTP 422
[Asserts]
jsonpath "$.errors[*].path" contains "id"

# Équipe inconnue → 404 en JSON ; identifiant non numérique → 404
GET {{host}}/api/teams/{{vsa_id}}/versus/999999
HTTP 404
[Asserts]
header "Content-Type" contains "application/json"

GET {{host}}/api/teams/999999/versus/{{vsb_id}}
HTTP 404

GET {{host}}/api/teams/{{vsa_id}}/versus/abc
HTTP 404

# ── Le classement ────────────────────────────────────────────────────────────

POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{ "name": "Top Reykjavik", "tag": "TRK", "country": "IS" }
HTTP 201
[Captures]
trk_id: jsonpath "$.id"

POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{ "name": "Top Wellington", "tag": "TWL", "country": "NZ" }
HTTP 201
[Captures]
twl_id: jsonpath "$.id"

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Top_Delta", "country": "IS", "rating": 2990, "teamId": {{trk_id}} }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Top_Foxtrot", "country": "NZ", "rating": 2980 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Top_Alpha", "country": "IS", "rating": 2970, "teamId": {{trk_id}} }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Top_Bravo", "country": "NZ", "rating": 2960, "teamId": {{twl_id}} }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Top_Charlie", "country": "IS", "rating": 2950 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Top_Echo", "country": "NZ", "rating": 1005, "teamId": {{twl_id}} }
HTTP 201

# Les 3 meilleurs, toutes équipes confondues, du plus fort au moins fort
GET {{host}}/api/players/top?limit=3
HTTP 200
[Asserts]
jsonpath "$" count == 3
jsonpath "$[0].nickname" == "Top_Delta"
jsonpath "$[1].nickname" == "Top_Foxtrot"
jsonpath "$[2].nickname" == "Top_Alpha"
jsonpath "$[0].rating" == 2990
# Même représentation qu'ailleurs : l'équipe imbriquée, jamais la date de naissance
jsonpath "$[0].team.tag" == "TRK"
jsonpath "$[0].birthDate" not exists

# Filtre par pays (limite par défaut : 10)
GET {{host}}/api/players/top?country=IS
HTTP 200
[Asserts]
jsonpath "$" count == 3
jsonpath "$[0].nickname" == "Top_Delta"
jsonpath "$[1].nickname" == "Top_Alpha"
jsonpath "$[2].nickname" == "Top_Charlie"

# Le pays est accepté en minuscules
GET {{host}}/api/players/top?country=nz&limit=1
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].nickname" == "Top_Foxtrot"

# limit doit être un entier entre 1 et 50
GET {{host}}/api/players/top?limit=0
HTTP 400

GET {{host}}/api/players/top?limit=abc
HTTP 400

GET {{host}}/api/players/top?limit=51
HTTP 400

# « top » n'est pas un identifiant : la route doit être déclarée avant /:id
GET {{host}}/api/players/top
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count <= 10
