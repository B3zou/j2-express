# Antisèche pg et zod

Deux frontières de votre API : la base (PostgreSQL via `pg`, du SQL écrit à la main) et le client (zod, qui vérifie à l'exécution ce que TypeScript ne peut plus vérifier). Références : https://node-postgres.com · https://zod.dev

## pg : Pool et `query<T>()`

```ts
// src/db.ts (extrait)
import { Pool } from 'pg';
export const pool = new Pool({ connectionString: process.env.DATABASE_URL });

export async function query<T>(text: string, values: unknown[] = []): Promise<T[]> {
  const result = await pool.query<T & Record<string, unknown>>(text, values);
  return result.rows; // toujours un tableau (vide si rien), jamais null
}
```

```ts
import { query } from '../db.js';
const rows = await query<{ id: number; name: string }>('SELECT id, name FROM game WHERE genre = $1', ['fps']);
const [one] = await query<Game>('SELECT id, name, genre, team_size AS "teamSize" FROM game WHERE id = $1', [3]);
// one : Game | undefined → return one ?? null
```
- Le pool garde quelques connexions ouvertes et les prête à chaque requête ; vous ne gérez rien.
- `<T>` est une **promesse faite au compilateur** : si la requête renvoie `team_size`, `row.teamSize` vaut `undefined`. D'où les alias.
- `count(*)`, `sum()` (bigint, numeric) reviennent en **chaîne** : `Number(row.count)`. Une colonne `json`/`jsonb` revient déjà décodée. Une colonne `DATE` revient en objet `Date` : `to_char(birth_date, 'YYYY-MM-DD')` ou `birth_date::text` pour une chaîne.

## Requêtes paramétrées et injection SQL

```ts
// JAMAIS : la valeur du client devient du SQL (?q=' OR '1'='1 → toutes les lignes, ou pire)
await query(`SELECT * FROM game WHERE name = '${q}'`);
// TOUJOURS : $1, $2… ; le texte et les valeurs voyagent séparément, la valeur reste une valeur
await query('SELECT * FROM game WHERE name = $1 AND genre = $2', [q, genre]);
```
Seules les **valeurs** peuvent être des paramètres. Un nom de colonne, de table, ou `ASC`/`DESC` passe par une **liste blanche** :

```ts
const SORTS = { name: 'name', genre: 'genre', size: 'team_size' } as const;
const sort = SORTS[String(req.query.sort) as keyof typeof SORTS] ?? 'name'; // jamais la valeur brute
const dir = req.query.dir === 'desc' ? 'DESC' : 'ASC';
await query<Game>(`SELECT id, name, genre, team_size AS "teamSize" FROM game ORDER BY ${sort} ${dir}`);
```

## Recettes SQL

```sql
-- alias snake_case → camelCase (guillemets obligatoires pour garder la majuscule)
SELECT id, name, team_size AS "teamSize" FROM game;

-- LIKE / ILIKE (insensible à la casse) : les % vont DANS la valeur, pas dans le texte SQL
--   query('… WHERE name ILIKE $1', [`%${q}%`])
SELECT id, name FROM game WHERE name ILIKE $1 ORDER BY name;

-- comparer sans tenir compte de la casse
SELECT id FROM game WHERE upper(genre) = upper($1);

-- RETURNING : récupérer la ligne écrite sans second SELECT
INSERT INTO game (name, genre, team_size) VALUES ($1, $2, $3) RETURNING id, name, genre, team_size AS "teamSize";
UPDATE game SET name = $2 WHERE id = $1 RETURNING id, name;
DELETE FROM game WHERE id = $1 RETURNING id;

-- pagination : LIMIT / OFFSET (offset = (page - 1) * limit), et le total en une seule requête
SELECT id, name, count(*) OVER() AS total FROM game ORDER BY name LIMIT $1 OFFSET $2;
--   total revient sur chaque ligne (en chaîne) : Number(rows[0]?.total ?? 0) ; page vide → 0 (ou comptage séparé) :
SELECT count(*) AS count FROM game WHERE genre = $1;
```

### Imbriquer avec `LEFT JOIN` + `json_build_object` / `json_agg`

Exemple neutre : des auteurs (`author`) et leurs livres (`book.author_id`, nullable).

```sql
-- un objet imbriqué (plusieurs → un) : chaque livre porte son auteur, ou null
SELECT b.id, b.title,
       CASE WHEN a.id IS NULL THEN NULL
            ELSE json_build_object('id', a.id, 'name', a.name) END AS author
  FROM book b
  LEFT JOIN author a ON a.id = b.author_id
 ORDER BY b.title;

-- un tableau imbriqué (un → plusieurs) : un auteur avec ses livres, [] s'il n'en a pas
SELECT a.id, a.name,
       COALESCE(
         json_agg(json_build_object('id', b.id, 'title', b.title) ORDER BY b.title)
           FILTER (WHERE b.id IS NOT NULL),
         '[]') AS books
  FROM author a
  LEFT JOIN book b ON b.author_id = a.id
 WHERE a.id = $1
 GROUP BY a.id;
```
- `LEFT JOIN` garde les auteurs sans livre ; sans `FILTER`, `json_agg` renverrait `[null]`.
- Toute colonne non agrégée doit être dans `GROUP BY` (`a.id` suffit : clé primaire).
- Côté TypeScript, `books` arrive déjà en tableau d'objets : `interface AuthorWithBooks { id: number; name: string; books: { id: number; title: string }[] }`.

## BaseRepository<T> (`src/repository.ts`)

| Membre | Signature | SQL généré |
|---|---|---|
| `new BaseRepository<T>(table, columns, orderBy = 'id')` | | `columns` : les colonnes lues, avec alias (`'team_size AS "teamSize"'`) |
| `findAll(page = 1, limit = 10)` | `Promise<T[]>` | `SELECT cols FROM t ORDER BY orderBy LIMIT $1 OFFSET $2` |
| `count()` | `Promise<number>` | `SELECT count(*) FROM t` |
| `findOne(id)` | `Promise<T \| null>` | `… WHERE id = $1` ; le routeur fait le 404 |
| `insert(data)` | `Promise<T>` | `INSERT … RETURNING cols` ; clés de `data` → colonnes en snake_case |
| `update(id, data)` | `Promise<T \| null>` | `UPDATE … SET k = $2, … WHERE id = $1 RETURNING cols` ; `{}` → `findOne(id)` |
| `delete(id)` | `Promise<boolean>` | `DELETE … RETURNING id` |
| `select` (getter `protected`) | `string` | `SELECT cols FROM t` : le début de vos requêtes maison |
| `toSnakeCase(key)` (fonction exportée) | `string` | `'teamSize'` → `'team_size'` : la seule conversion automatique |

`insert`/`update` supposent des clés **connues** : appelez-les seulement avec un corps passé par `validate(schema)` (zod retire les clés inconnues). Les alias de `columns` servent aussi au `RETURNING`.

### L'étendre : une sous-classe, et du SQL à la main

```ts
// src/games/game.repository.ts (le fichier du squelette, plus une méthode)
import { query } from '../db.js';
import { BaseRepository } from '../repository.js';
import type { Game, Genre } from './game.schema.js';

class GameRepository extends BaseRepository<Game> {
  constructor() {
    super('game', ['id', 'name', 'genre', 'team_size AS "teamSize"'], 'name'); // table, colonnes lues, tri
  }

  findByGenre(genre: Genre): Promise<Game[]> {
    return query<Game>(`${this.select} WHERE genre = $1 ORDER BY name`, [genre]);
  }

  // une méthode qui renvoie une autre forme que T : son propre type de ligne
  async countByGenre(): Promise<{ genre: Genre; total: number }[]> {
    const rows = await query<{ genre: Genre; total: string }>('SELECT genre, count(*) AS total FROM game GROUP BY genre');
    return rows.map((r) => ({ genre: r.genre, total: Number(r.total) }));
  }
}
export const games = new GameRepository();
```
Quand la lecture d'un élément doit être enrichie (jointure, tableau imbriqué), redéfinissez `findOne` dans la sous-classe (`override async findOne(id: number): Promise<Game | null> { … }`) : le routeur ne change pas.

## Erreurs PostgreSQL → HTTP (`translatePgError` dans `db.ts`, appelée par `errorHandler`)

| Code pg | Contrainte | Réponse | `path` |
|---|---|---|---|
| `23505` | UNIQUE (nom, tag, pseudo déjà pris) | 409 `Conflict`, `already exists` | la colonne, extraite de `detail: Key (name)=(…)`, en camelCase |
| `23503` | clé étrangère (la ligne référencée n'existe pas) | 422 `Validation Failed`, `does not exist` | idem (`team_id` → `teamId`) |
| `23514` | CHECK (valeur hors bornes) | 422 `Validation Failed`, `invalid value` | la colonne |
| autre | | 500, détail dans `make logs` | |

Rien à attraper dans le routeur : laissez l'erreur remonter. `relation "x" does not exist` = la table manque (`make db-reset` après avoir modifié `db/schema.sql`).

## zod 4

```ts
import { z } from 'zod';

export const GameSchema = z.object({
  name: z.string().trim().min(1).max(100),
  genre: z.enum(['moba', 'fps', 'fighting', 'sports', 'racing', 'strategy']),
  teamSize: z.number().int().min(1).max(10),
});
export type GameInput = z.infer<typeof GameSchema>;  // { name: string; genre: 'moba' | …; teamSize: number }
export const GamePatchSchema = GameSchema.partial(); // PATCH : tous les champs facultatifs
```

| Besoin | zod |
|---|---|
| chaîne, bornes, motif | `z.string().trim().min(2).max(30)`, `.regex(/^[A-Z]{2}$/)`, `.toUpperCase()` |
| nombre | `z.number().int().positive()`, `.min(0).max(3000)`, `.nonnegative()` |
| booléen, littéral | `z.boolean()`, `z.literal('played')` |
| choix fermé | `z.enum(['scheduled', 'played'])` (`schema.options` donne le tableau) |
| facultatif (absent ou `undefined`) | `.optional()` |
| `null` accepté | `.nullable()` (`T \| null`) ; `.nullish()` (`T \| null \| undefined`) |
| valeur par défaut si absent | `.default(1000)` (en sortie, le champ n'est plus optionnel) |
| date `YYYY-MM-DD` | `z.iso.date()` (reste une chaîne) ; `z.iso.datetime()` pour l'ISO complet |
| e-mail, URL | `z.email()`, `z.url()` |
| query params (chaînes → nombres) | `z.coerce.number().int().min(1).default(1)` : `'2'` → `2`, `'abc'` → erreur |
| règle métier sur un champ | `z.iso.date().refine((d) => new Date(d) < new Date(), { message: 'must be in the past' })` |
| règle entre champs | `z.object({ a: z.number(), b: z.number() }).refine((o) => o.a !== o.b, { message: 'must differ', path: ['b'] })` |
| dériver un schéma | `.partial()`, `.pick({ name: true })`, `.omit({ id: true })`, `.extend({ x: z.string() })` |
| clés inconnues | retirées par défaut (`"id": 424242` disparaît) ; `.strict()` pour les refuser |
| tableau, objet imbriqué | `z.array(z.number().int())`, `z.object({ team: z.object({ id: z.number() }) })` |

```ts
// Query params : tout arrive en chaîne, d'où z.coerce ; validateQuery(schema) répond 400 et range le résultat dans res.locals.query
export const BookQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(10),
  q: z.string().trim().min(1).optional(),
  authorId: z.coerce.number().int().positive().optional(),
});
export type BookQuery = z.infer<typeof BookQuerySchema>; // { page: number; limit: number; q?: string; authorId?: number }
```

### `safeParse` et `parse`

```ts
const result = GameSchema.safeParse(req.body);
if (!result.success) {
  result.error.issues; // [{ code: 'too_big', path: ['teamSize'], message: 'Too big: expected number to be <=10' }]
} else {
  result.data;         // GameInput, nettoyé (clés inconnues retirées, chaînes trim)
}
const data = GameSchema.parse(req.body); // renvoie les données ou lève une ZodError (→ 422 par errorHandler)
```
Dans un routeur, vous n'appelez ni l'un ni l'autre : `validate(schema)` (corps → 422, `req.body` remplacé par `result.data`) et `validateQuery(schema)` (query → 400, résultat dans `res.locals.query`) le font ; le format `{ path: issue.path.join('.'), message }` est celui des tests.

## zod ⇄ OpenAPI

| zod (vérifie à l'exécution) | OpenAPI / JSON Schema (documente) |
|---|---|
| `z.object({ … })` | `type: object`, `properties` |
| champ obligatoire / `.optional()` | présent / absent de `required` |
| `z.string().min(1).max(100)` | `type: string, minLength: 1, maxLength: 100` |
| `z.string().regex(/^[A-Z]{2}$/)` | `type: string, pattern: '^[A-Z]{2}$'` |
| `z.number().int().min(1).max(10)` | `type: integer, minimum: 1, maximum: 10` |
| `z.number()` | `type: number` |
| `z.enum(['moba', 'fps', …])` | `type: string, enum: [moba, fps, …]` |
| `.nullable()` | `type: [string, 'null']` (OpenAPI 3.1) |
| `.default(1000)` | `default: 1000` |
| `z.iso.date()` / `z.iso.datetime()` | `type: string, format: date` / `format: date-time` |
| `z.email()` | `type: string, format: email` |
| `z.array(X)` | `type: array, items: X` |

Deux descriptions du même contrat : quand vous changez l'une, changez l'autre.
