# ─────────────────────────────────────────────────────────────────────────────
# J1, repris au J2 · Le contrat OpenAPI (api/openapi.yaml), servi sur /api/openapi.json
# Attendu : la spécification décrit TOUTES vos routes (Team, Player, Match), leurs schémas
#           et leurs erreurs. Swagger UI (/api/docs) doit les afficher.
# ─────────────────────────────────────────────────────────────────────────────

# La spécification est servie en JSON (déjà le cas pour Game : regardez-la dans le navigateur)
GET {{host}}/api/openapi.json
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.openapi" startsWith "3.1"
jsonpath "$.info.title" == "GG League API"
jsonpath "$.paths['/api/games'].get" exists
jsonpath "$.paths['/api/games'].post.requestBody.content['application/json'].schema['$ref']" == "#/components/schemas/GameInput"
jsonpath "$.components.schemas.Game.properties.id.readOnly" == true

# Team : les chemins, les deux schémas, les erreurs
GET {{host}}/api/openapi.json
HTTP 200
[Asserts]
jsonpath "$.paths['/api/teams'].get" exists
jsonpath "$.paths['/api/teams'].get.parameters[*].name" contains "country"
jsonpath "$.paths['/api/teams'].post.responses['201']" exists
jsonpath "$.paths['/api/teams'].post.responses['409']" exists
jsonpath "$.paths['/api/teams'].post.responses['422']" exists
jsonpath "$.paths['/api/teams/{id}'].get.responses['404']" exists
jsonpath "$.paths['/api/teams/{id}'].patch" exists
jsonpath "$.paths['/api/teams/{id}'].delete.responses['204']" exists
jsonpath "$.paths['/api/teams/{id}/versus/{opponentId}'].get" exists
jsonpath "$.components.schemas.Team.properties.players" exists
jsonpath "$.components.schemas.TeamInput.required" contains "tag"
jsonpath "$.components.schemas.TeamInput.properties.tag.pattern" exists

# Player : pagination documentée, date de naissance en écriture seulement
GET {{host}}/api/openapi.json
HTTP 200
[Asserts]
jsonpath "$.paths['/api/players'].get.parameters[*].name" contains "page"
jsonpath "$.paths['/api/players'].get.parameters[*].name" contains "q"
jsonpath "$.paths['/api/players'].get.responses['200'].headers['X-Total-Count']" exists
jsonpath "$.paths['/api/players/top'].get" exists
jsonpath "$.paths['/api/players/{id}'].get" exists
jsonpath "$.components.schemas.Player.properties.team" exists
jsonpath "$.components.schemas.Player.properties.birthDate" not exists
jsonpath "$.components.schemas.PlayerInput.properties.birthDate" exists
jsonpath "$.components.schemas.PlayerInput.properties.teamId" exists

# Match : la création, le filtre, l'action « play » et ses erreurs
GET {{host}}/api/openapi.json
HTTP 200
[Asserts]
jsonpath "$.paths['/api/matches'].post" exists
jsonpath "$.paths['/api/matches'].get.parameters[*].name" contains "status"
jsonpath "$.paths['/api/matches/{id}'].get" exists
jsonpath "$.paths['/api/matches/{id}/play'].post.responses['200']" exists
jsonpath "$.paths['/api/matches/{id}/play'].post.responses['409']" exists
jsonpath "$.paths['/api/matches/{id}/play'].post.responses['422']" exists
jsonpath "$.components.schemas.Match.properties.status.enum" contains "played"
jsonpath "$.components.schemas.MatchInput.required" contains "teamAId"

# J2 : l'authentification est documentée (fourni) ; Swagger UI affiche le bouton Authorize et les cadenas
GET {{host}}/api/openapi.json
HTTP 200
[Asserts]
jsonpath "$.components.securitySchemes.bearerAuth.scheme" == "bearer"
jsonpath "$.paths['/api/auth/register'].post" exists
jsonpath "$.paths['/api/auth/login'].post.responses['200']" exists
jsonpath "$.paths['/api/auth/me'].get.security[0].bearerAuth" exists
jsonpath "$.paths['/api/teams'].post.security[0].bearerAuth" exists
jsonpath "$.paths['/api/teams'].post.responses['401']" exists
jsonpath "$.paths['/api/teams'].get.security" not exists

# Swagger UI
GET {{host}}/api/docs/
HTTP 200
[Asserts]
header "Content-Type" contains "text/html"
