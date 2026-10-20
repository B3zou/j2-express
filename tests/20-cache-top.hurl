# ─────────────────────────────────────────────────────────────────────────────
# J2 · TD Redis étape 1 — Un cache à la main sur GET /api/players/top
# (Les joueurs de ce fichier ont un pays à eux, QA, pour ne pas dépendre des autres tests : la base est partagée.)
# Attendu : premier appel → X-Cache: MISS (la base est interrogée, la réponse stockée 60 s)
#           deuxième appel identique → X-Cache: HIT, même corps, la base n'est pas interrogée
#           une query différente est une autre clé ; une query invalide → 400 sans X-Cache
# ─────────────────────────────────────────────────────────────────────────────

POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t20@test.dev", "password": "password-20" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t20@test.dev", "password": "password-20" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Cache_Alpha", "country": "QA", "rating": 2500 }
HTTP 201

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Cache_Bravo", "country": "QA", "rating": 2400 }
HTTP 201

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Cache_Charlie", "country": "QA", "rating": 2300 }
HTTP 201

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Cache_Delta", "country": "QA", "rating": 2200 }
HTTP 201

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Cache_Echo", "country": "QA", "rating": 2100 }
HTTP 201

POST {{host}}/api/players
Content-Type: application/json
Authorization: Bearer {{token}}
{ "nickname": "Cache_Foxtrot", "country": "QA", "rating": 2050 }
HTTP 201

# Premier appel : MISS, et la réponse est celle d'hier
GET {{host}}/api/players/top?country=QA&limit=4
HTTP 200
[Captures]
body1: body
[Asserts]
header "X-Cache" == "MISS"
header "Content-Type" contains "application/json"
jsonpath "$" count == 4
jsonpath "$[0].nickname" == "Cache_Alpha"

# Deuxième appel identique : HIT, corps identique octet pour octet
GET {{host}}/api/players/top?country=QA&limit=4
HTTP 200
[Asserts]
header "X-Cache" == "HIT"
header "Content-Type" contains "application/json"
body == {{body1}}
jsonpath "$[0].nickname" == "Cache_Alpha"

# Une autre query → une autre clé → MISS (sinon on servirait 4 joueurs à qui en demande 6)
GET {{host}}/api/players/top?country=QA&limit=6
HTTP 200
[Asserts]
header "X-Cache" == "MISS"
jsonpath "$" count == 6

GET {{host}}/api/players/top?country=QA&limit=6
HTTP 200
[Asserts]
header "X-Cache" == "HIT"
jsonpath "$" count == 6

# Une query invalide est refusée AVANT le cache : 400, et pas d'en-tête X-Cache
GET {{host}}/api/players/top?country=QA&limit=abc
HTTP 400
[Asserts]
header "X-Cache" not exists
