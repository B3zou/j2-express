# Antisèche OpenAPI 3.1

`api/openapi.yaml` est le contrat de votre API, écrit à la main (conception d'abord), servi sur `/api/openapi.json` et affiché par Swagger UI sur `/api/docs`. Référence : https://spec.openapis.org/oas/v3.1.0 · les schémas sont du JSON Schema : https://json-schema.org/understanding-json-schema

## La structure

```yaml
openapi: 3.1.0                 # la version de la SPÉCIFICATION
info:
  title: GG League API
  version: 1.0.0               # la version de VOTRE API
servers:
  - url: http://localhost:8000
tags: [{ name: Games }]        # regroupent les opérations dans Swagger UI (tags: [Games] sur chaque opération)
paths: {}                      # chemin → méthode → opération (parameters, requestBody, responses)
components:                    # ce qu'on réutilise : schemas, responses, parameters, securitySchemes
  schemas: {}
```

## Un chemin complet (exemple neutre : des livres)

```yaml
paths:
  /api/books:
    get:
      tags: [Books]
      summary: Liste des livres (paginée)
      parameters:
        - name: page
          in: query
          schema: { type: integer, minimum: 1, default: 1 }
        - { name: q, in: query, schema: { type: string, minLength: 1 } }
        - { name: X-Request-Id, in: header, schema: { type: string } }   # un en-tête de requête
      responses:
        '200':
          description: Les livres de la page, triés par titre
          headers:
            X-Total-Count: { description: 'Nombre total, toutes pages confondues', schema: { type: integer } }
          content:
            application/json:
              schema:
                type: array
                items: { $ref: '#/components/schemas/Book' }
        '400':
          $ref: '#/components/responses/BadRequest'
    post:
      tags: [Books]
      summary: Créer un livre
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/BookInput' }
      responses:
        '201':
          description: Livre créé
          headers:
            Location: { schema: { type: string, example: /api/books/6 } }
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Book' }
        '409': { $ref: '#/components/responses/Conflict' }
        '415': { $ref: '#/components/responses/UnsupportedMediaType' }
        '422': { $ref: '#/components/responses/ValidationError' }

  /api/books/{id}:
    parameters:                          # commun à toutes les méthodes du chemin
      - $ref: '#/components/parameters/id'
    get:
      tags: [Books]
      summary: Un livre
      responses:
        '200':
          description: Le livre demandé
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Book' }
        '404': { $ref: '#/components/responses/NotFound' }
    delete:
      summary: Supprimer un livre
      responses:
        '204': { description: Livre supprimé }      # pas de content
        '404': { $ref: '#/components/responses/NotFound' }
```
Une action (`POST /api/books/{id}/publish`) se décrit comme un `post` sans `requestBody`, avec `'200'` (la ressource modifiée), `'404'` et `'409'`.

Un paramètre `in: path` est toujours `required: true` et apparaît dans le chemin entre accolades : `/api/books/{id}`. `{ … }` sur une ligne et le bloc indenté sont deux écritures YAML du même objet.

## Les schémas (`components.schemas`)

```yaml
components:
  parameters:
    id: { name: id, in: path, required: true, schema: { type: integer, minimum: 1 } }

  schemas:
    Book:                                # ce que l'API renvoie
      type: object
      required: [id, title, status, pages, authorId, author]
      properties:
        id: { type: integer, readOnly: true, example: 1 }
        title: { type: string, minLength: 1, maxLength: 100, example: Dune }
        isbn: { type: string, pattern: '^[0-9]{13}$' }
        status: { type: string, enum: [draft, published] }
        pages: { type: integer, minimum: 1 }
        authorId: { type: [integer, 'null'] }           # nullable en 3.1 : une liste de types, 'null' ENTRE QUOTES
        author:                                          # objet imbriqué, ou null
          type: [object, 'null']
          properties: { id: { type: integer }, name: { type: string } }

    BookInput:                           # ce que le client envoie : sans id, avec ses propres required
      type: object
      required: [title]
      properties:
        title: { type: string, minLength: 1, maxLength: 100 }
        pages: { type: integer, minimum: 1, default: 100 }
        authorId: { type: [integer, 'null'] }

    BookPatch:                           # PATCH : mêmes propriétés que BookInput, sans required
      type: object
      properties: { title: { type: string, minLength: 1, maxLength: 100 }, pages: { type: integer, minimum: 1 } }
```
Le schéma `Error` (`{ title, status, errors?: [{ path, message }] }`) est déjà dans le squelette.

| Mot-clé | Rôle |
|---|---|
| `type` | `string`, `integer`, `number`, `boolean`, `array`, `object` ; nullable en 3.1 : `[integer, 'null']` |
| `required: [a, b]` | liste des propriétés obligatoires, au niveau de l'**objet** |
| `properties`, `items` | les propriétés d'un objet ; le schéma d'un élément de tableau |
| `enum` | valeurs permises |
| `minimum`, `maximum`, `minLength`, `maxLength`, `pattern`, `format` (`date`, `date-time`, `email`) | contraintes |
| `readOnly: true` | géré par le serveur (`id`) ; en 3.1, ne retire PAS la propriété de `required` : d'où un schéma `XInput` séparé |
| `example`, `default`, `description` | documentation (visible dans Swagger UI) |
| `$ref: '#/components/schemas/Book'` | réutiliser ; un `$ref` remplace tout le reste de l'objet |

## Réponses réutilisables (`components.responses`)

```yaml
components:
  responses:
    NotFound:
      description: La ressource n'existe pas
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
```
Puis dans une opération : `'404': { $ref: '#/components/responses/NotFound' }`. Le squelette définit déjà `BadRequest`, `NotFound`, `Conflict`, `UnsupportedMediaType`, `ValidationError` et le paramètre `id` : réutilisez-les.

## Erreurs fréquentes

| Symptôme | Cause et correction |
|---|---|
| `/api/openapi.json` et Swagger UI répondent 500 `openapi.yaml invalide` (le message du parseur est dans `detail`) | indentation : 2 espaces, jamais de tabulation ; une valeur qui contient `:` ou `#` va entre quotes |
| un code de statut est ignoré ou refusé | les codes s'écrivent entre quotes : `'200'`, `'404'` (sinon YAML lit un nombre) |
| le test `06-openapi` échoue sur une réponse 404, 409 ou 422 | documentez aussi les erreurs : `404` sur `/{id}`, `409` et `422` sur les écritures, `400` sur les filtres |
| `required: true` sous une propriété | `required` est une **liste au niveau de l'objet** ; `required: true` n'existe que pour un paramètre ou un `requestBody` |
| `type: [integer, null]` accepté partout | `null` sans quotes est la valeur YAML nulle, pas le type : `'null'` |
| « could not resolve reference » | chemin exact, sensible à la casse, entre quotes à cause du `#` : `'#/components/schemas/Book'` |

## Comment la spec est servie (`src/docs.router.ts`, fourni)

```ts
// forme simplifiée : le fichier réel relit le YAML à chaque requête
import { readFileSync } from 'node:fs';
import { Router } from 'express';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yaml';

function loadSpec(): Record<string, unknown> {
  return YAML.parse(readFileSync(new URL('../openapi.yaml', import.meta.url), 'utf8'));
}

export const docsRouter = Router();
docsRouter.get('/openapi.json', (_req, res) => { res.json(loadSpec()); }); // GET /api/openapi.json
docsRouter.use('/docs', swaggerUi.serve, swaggerUi.setup(loadSpec()));     // GET /api/docs  (app.ts : app.use('/api', docsRouter))
```
Le YAML est **relu à chaque requête** : modifiez-le, rechargez Swagger UI, c'est à jour (un YAML cassé donne une erreur 500 dont le détail est dans `make logs`). Vérifiez : `curl -s localhost:8000/api/openapi.json | jq '.paths | keys'`. Dans Swagger UI, « Try it out » envoie de vraies requêtes à votre API.

## Aperçu : la sécurité (vous verrez ça au J2)

```yaml
components:
  securitySchemes:
    bearerAuth: { type: http, scheme: bearer, bearerFormat: JWT }
security: [{ bearerAuth: [] }]   # global : toutes les opérations exigent un jeton ; security: [] sur une opération l'en dispense
```
Swagger UI affiche alors un bouton « Authorize » ; les réponses `401` et `403` rejoindront `components.responses`.
