# ─────────────────────────────────────────────────────────────────────────────
# J2 · TD Redis étape 3 — Invalider le cache à l'écriture
# Attendu : après POST/PATCH/DELETE sur un joueur OU une équipe, les entrées /api/players* ET /api/teams*
#           du cache sont supprimées (les deux familles dépendent l'une de l'autre) : le prochain GET est un MISS
# ─────────────────────────────────────────────────────────────────────────────

POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t22@test.dev", "password": "password-22" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t22@test.dev", "password": "password-22" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"

POST {{host}}/api/teams
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "Invalidate Alpha", "tag": "IVA", "country": "IV" }
HTTP 201
[Captures]
alpha_id: jsonpath "$.id"

POST {{host}}/api/teams
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "Invalidate Beta", "tag": "IVB", "country": "IV" }
HTTP 201
[Captures]
beta_id: jsonpath "$.id"

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Inv_One", "country": "QB", "rating": 2800, "teamId": {{alpha_id}} }
HTTP 201

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Inv_Two", "country": "QB", "rating": 1200, "teamId": {{beta_id}} }
HTTP 201

# On chauffe le cache
GET {{host}}/api/players/top?country=QB&limit=1
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$[0].nickname" == "Inv_One"

GET {{host}}/api/players/top?country=QB&limit=1
HTTP 200
[Asserts]
header "X-Cache" == "HIT"

GET {{host}}/api/teams?country=IV
HTTP 200
[Asserts]
header "X-Cache" == "MISS"

GET {{host}}/api/teams?country=IV
HTTP 200
[Asserts]
header "X-Cache" == "HIT"

GET {{host}}/api/teams/{{alpha_id}}/versus/{{beta_id}}?seed=1
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$.teamA.rating" == 2800

# ── Un nouveau joueur, plus fort : le classement doit changer immédiatement ──
POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Inv_Three", "country": "QB", "rating": 2999, "teamId": {{alpha_id}} }
HTTP 201
[Captures]
three_url: header "Location"

GET {{host}}/api/players/top?country=QB&limit=1
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$[0].nickname" == "Inv_Three"

# … et le niveau moyen de l'équipe aussi (le versus dépend des joueurs → invalidé lui aussi)
GET {{host}}/api/teams/{{alpha_id}}/versus/{{beta_id}}?seed=1
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$.teamA.rating" == 2900

# ── Modifier une équipe : la liste des équipes est rafraîchie ──
PATCH {{host}}/api/teams/{{alpha_id}}
Content-Type: application/json
Authorization: Bearer {{token}}
{ "name": "Invalidate Alpha Renamed" }
HTTP 200

GET {{host}}/api/teams?country=IV
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$[*].name" contains "Invalidate Alpha Renamed"
jsonpath "$[*].name" not contains "Invalidate Alpha"

# ── Le classement aussi : la vue d'un joueur contient le nom de son équipe ──
GET {{host}}/api/players/top?country=QB&limit=1
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$[0].team.name" == "Invalidate Alpha Renamed"

GET {{host}}/api/players/top?country=QB&limit=1
HTTP 200
[Asserts]
header "X-Cache" == "HIT"

# ── Supprimer un joueur : le classement est rafraîchi ──
DELETE {{host}}{{three_url}}
Authorization: Bearer {{token}}
HTTP 204

GET {{host}}/api/players/top?country=QB&limit=1
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$[0].nickname" == "Inv_One"

# ── Une lecture n'invalide rien ──
GET {{host}}/api/players/top?country=QB&limit=1
HTTP 200
[Asserts]
header "X-Cache" == "HIT"
