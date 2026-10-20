# ─────────────────────────────────────────────────────────────────────────────
# J1, repris au J2 · Exemple fourni — la ressource Game (api/src/games/)
# Ce fichier doit être VERT dès le début : il vérifie votre environnement et montre
# la forme exacte attendue (codes, en-têtes, erreurs). Lancer : make test f=00
# ─────────────────────────────────────────────────────────────────────────────

# ── J2 : les écritures exigent un jeton. Celui-ci est signé avec le secret de l'API de test (test-secret),
#    SANS date d'expiration, pour que ce fichier témoin reste vert toute la journée sans dépendre de /login :
#    avant l'étape 4 l'en-tête est ignoré, après il est vérifié. Vous saurez en fabriquer un à l'étape 2.
GET {{host}}/api/health
[Options]
variable: witness=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwiZW1haWwiOiJ3aXRuZXNzQHRlc3QuZGV2IiwiaWF0IjoxNzkyNTE5NDYyfQ.s3ZkQjKuCqMpOHbT-70_uKIZWNol_xdQbPdSpQ5K_Vs
HTTP 200


# Création → 201 Created + en-tête Location vers la nouvelle ressource
POST {{host}}/api/games
Authorization: Bearer {{witness}}
Content-Type: application/json
{
  "name": "Test Game Alpha",
  "genre": "sports",
  "teamSize": 3,
  "id": 424242
}
HTTP 201
[Captures]
game_url: header "Location"
game_id: jsonpath "$.id"
[Asserts]
header "Location" matches "^/api/games/\\d+$"
header "Content-Type" contains "application/json"
jsonpath "$.name" == "Test Game Alpha"
jsonpath "$.genre" == "sports"
jsonpath "$.teamSize" == 3
# l'id est choisi par la base, jamais par le client (zod retire les clés inconnues)
jsonpath "$.id" != 424242

# Lecture d'un élément
GET {{host}}{{game_url}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{game_id}}
jsonpath "$.name" == "Test Game Alpha"

# Collection : un tableau JSON, trié par nom
GET {{host}}/api/games
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$[*].name" contains "Test Game Alpha"

# Filtre par genre
GET {{host}}/api/games?genre=sports
HTTP 200
[Asserts]
jsonpath "$[*].name" contains "Test Game Alpha"
jsonpath "$[*].genre" not contains "fps"

GET {{host}}/api/games?genre=jeu-de-l-oie
HTTP 400

# Mise à jour partielle (PATCH) : seuls les champs envoyés changent
PATCH {{host}}{{game_url}}
Authorization: Bearer {{witness}}
Content-Type: application/json
{
  "teamSize": 2
}
HTTP 200
[Asserts]
jsonpath "$.teamSize" == 2
jsonpath "$.name" == "Test Game Alpha"

# PATCH vide : rien ne change, et ce n'est pas une erreur
PATCH {{host}}{{game_url}}
Authorization: Bearer {{witness}}
Content-Type: application/json
{}
HTTP 200
[Asserts]
jsonpath "$.teamSize" == 2

# Validation → 422 avec la liste des problèmes : { title, status, errors: [{ path, message }] }
POST {{host}}/api/games
Authorization: Bearer {{witness}}
Content-Type: application/json
{
  "name": "",
  "genre": "fps",
  "teamSize": 42
}
HTTP 422
[Asserts]
jsonpath "$.title" == "Validation Failed"
jsonpath "$.status" == 422
jsonpath "$.errors[*].path" contains "name"
jsonpath "$.errors[*].path" contains "teamSize"
jsonpath "$.errors[0].message" isString

# Mauvais type (genre inconnu) → 422 aussi
POST {{host}}/api/games
Authorization: Bearer {{witness}}
Content-Type: application/json
{
  "name": "Test Game Beta",
  "genre": "jeu-de-l-oie",
  "teamSize": 2
}
HTTP 422
[Asserts]
jsonpath "$.errors[0].path" == "genre"

# Champ manquant → 422
POST {{host}}/api/games
Authorization: Bearer {{witness}}
Content-Type: application/json
{
  "genre": "fps",
  "teamSize": 2
}
HTTP 422
[Asserts]
jsonpath "$.errors[0].path" == "name"

# Unicité du nom (contrainte UNIQUE de PostgreSQL) → 409 Conflict
POST {{host}}/api/games
Authorization: Bearer {{witness}}
Content-Type: application/json
{
  "name": "Test Game Alpha",
  "genre": "sports",
  "teamSize": 3
}
HTTP 409
[Asserts]
jsonpath "$.title" == "Conflict"
jsonpath "$.status" == 409
jsonpath "$.errors[0].path" == "name"

# PATCH invalide → 422, et rien n'est enregistré
PATCH {{host}}{{game_url}}
Authorization: Bearer {{witness}}
Content-Type: application/json
{
  "teamSize": 99
}
HTTP 422

GET {{host}}{{game_url}}
HTTP 200
[Asserts]
jsonpath "$.teamSize" == 2

# Un POST sans corps du tout (Swagger UI et les navigateurs ajoutent Content-Length: 0) :
# ce n'est pas un 415, c'est un corps vide → 422
POST {{host}}/api/games
Authorization: Bearer {{witness}}
Content-Length: 0
HTTP 422

# Mauvais type de contenu → 415 Unsupported Media Type
POST {{host}}/api/games
Authorization: Bearer {{witness}}
Content-Type: text/plain
```
name=Oops
```
HTTP 415

# JSON illisible → 400 Bad Request
POST {{host}}/api/games
Authorization: Bearer {{witness}}
Content-Type: application/json
```
{"name": "Oops",
```
HTTP 400
[Asserts]
jsonpath "$.status" == 400

# Ressource inexistante → 404... en JSON
GET {{host}}/api/games/999999
HTTP 404
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.title" == "Game not found"
jsonpath "$.status" == 404

# L'id doit être un nombre → 404 aussi
GET {{host}}/api/games/abc
HTTP 404

# ... un entier « propre » (pas de 1.0, +1, 00001) ...
GET {{host}}/api/games/1.0
HTTP 404

# ... et dans les bornes de PostgreSQL (integer : 2 147 483 647 maximum)
GET {{host}}/api/games/2147483648
HTTP 404

# Une URL qui n'existe pas → 404 en JSON (middleware notFound)
GET {{host}}/api/nothing-here
HTTP 404
[Asserts]
header "Content-Type" contains "application/json"

# Suppression → 204 No Content, puis 404
DELETE {{host}}{{game_url}}
Authorization: Bearer {{witness}}
HTTP 204
[Asserts]
bytes count == 0

GET {{host}}{{game_url}}
HTTP 404

DELETE {{host}}{{game_url}}
Authorization: Bearer {{witness}}
HTTP 404
