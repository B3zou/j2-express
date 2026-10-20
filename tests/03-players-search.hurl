# ─────────────────────────────────────────────────────────────────────────────
# J1, repris au J2 · TD étape 5 — Recherche et pagination de /api/players
# Attendu : GET /api/players?page=&limit=&country=&teamId=&q=
#           10 joueurs par page (limit 1..50), tri par pseudo, total dans l'en-tête X-Total-Count,
#           400 Bad Request si un paramètre est invalide, q = recherche dans le pseudo (insensible à la casse)
# ─────────────────────────────────────────────────────────────────────────────

# ── J2 : ce fichier s'authentifie (les écritures exigent un jeton depuis l'étape 4 du TD JWT).
#    Tant que POST /api/auth/login n'existe pas, il est rouge : c'est normal, il revient au vert à l'étape 2.
POST {{host}}/api/auth/register
Content-Type: application/json
{ "email": "t03@test.dev", "password": "password-03" }
HTTP 201

POST {{host}}/api/auth/login
Content-Type: application/json
{ "email": "t03@test.dev", "password": "password-03" }
HTTP 200
[Captures]
token: jsonpath "$.accessToken"


POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot01", "country": "JP", "rating": 1010 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot02", "country": "JP", "rating": 1020 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot03", "country": "JP", "rating": 1030 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot04", "country": "JP", "rating": 1040 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot05", "country": "JP", "rating": 1050 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot06", "country": "JP", "rating": 1060 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot07", "country": "JP", "rating": 1070 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot08", "country": "JP", "rating": 1080 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot09", "country": "JP", "rating": 1090 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot10", "country": "JP", "rating": 1100 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot11", "country": "JP", "rating": 1110 }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Bot12", "country": "JP", "rating": 1120 }
HTTP 201

# Une équipe et deux joueurs, pour le filtre ?teamId=
POST {{host}}/api/teams
Authorization: Bearer {{token}}
Content-Type: application/json
{ "name": "Test Search Team", "tag": "TST", "country": "KR" }
HTTP 201
[Captures]
team_id: jsonpath "$.id"

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Search_A", "country": "KR", "teamId": {{team_id}} }
HTTP 201

POST {{host}}/api/players
Authorization: Bearer {{token}}
Content-Type: application/json
{ "nickname": "Test_Search_B", "country": "KR", "teamId": {{team_id}} }
HTTP 201

# Page 1 (par défaut) : 10 joueurs, triés par pseudo ; le total est dans l'en-tête
GET {{host}}/api/players?country=JP
HTTP 200
[Asserts]
header "X-Total-Count" == "12"
jsonpath "$" count == 10
jsonpath "$[0].nickname" == "Test_Bot01"
jsonpath "$[0].team" == null

# Page 2 : les 2 derniers
GET {{host}}/api/players?country=JP&page=2
HTTP 200
[Asserts]
header "X-Total-Count" == "12"
jsonpath "$" count == 2
jsonpath "$[0].nickname" == "Test_Bot11"

# Au-delà de la dernière page : liste vide (ce n'est pas une erreur)
GET {{host}}/api/players?country=JP&page=3
HTTP 200
[Asserts]
jsonpath "$" count == 0

# Taille de page au choix (1 à 50)
GET {{host}}/api/players?country=JP&page=2&limit=5
HTTP 200
[Asserts]
header "X-Total-Count" == "12"
jsonpath "$" count == 5
jsonpath "$[0].nickname" == "Test_Bot06"

# Le pays est accepté en minuscules
GET {{host}}/api/players?country=jp
HTTP 200
[Asserts]
header "X-Total-Count" == "12"

# Paramètres invalides → 400 Bad Request
GET {{host}}/api/players?page=0
HTTP 400
[Asserts]
jsonpath "$.title" == "Bad Request"
jsonpath "$.errors[*].path" contains "page"

GET {{host}}/api/players?page=abc
HTTP 400

GET {{host}}/api/players?limit=0
HTTP 400

GET {{host}}/api/players?limit=51
HTTP 400

GET {{host}}/api/players?limit=abc
HTTP 400

GET {{host}}/api/players?teamId=abc
HTTP 400

# Recherche dans le pseudo, insensible à la casse ; la pagination s'applique toujours
GET {{host}}/api/players?q=bot0
HTTP 200
[Asserts]
header "X-Total-Count" == "9"
jsonpath "$" count == 9

GET {{host}}/api/players?q=BOT12
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].nickname" == "Test_Bot12"

# La recherche se combine aux autres filtres
GET {{host}}/api/players?q=bot&country=JP&limit=50
HTTP 200
[Asserts]
jsonpath "$" count == 12

# Filtre par équipe
GET {{host}}/api/players?teamId={{team_id}}
HTTP 200
[Asserts]
header "X-Total-Count" == "2"
jsonpath "$" count == 2
jsonpath "$[0].nickname" == "Test_Search_A"
jsonpath "$[0].team.tag" == "TST"

GET {{host}}/api/players?teamId=999999
HTTP 200
[Asserts]
jsonpath "$" count == 0

# Sans filtre : la première page de tout le monde
GET {{host}}/api/players
HTTP 200
[Asserts]
header "X-Total-Count" exists
jsonpath "$" isCollection
jsonpath "$" count <= 10
