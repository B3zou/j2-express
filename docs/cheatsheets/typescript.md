# Antisèche TypeScript

Tout ce qu'il faut pour lire et écrire le code du cours (et du partiel) : d'abord le JavaScript moderne sur lequel TypeScript repose, puis les types, puis l'outillage du projet. Référence : https://www.typescriptlang.org/docs/handbook/

## 1. JavaScript moderne, l'essentiel

### Variables, fonctions, chaînes

```ts
const port = 3000;            // const : jamais réassigné (votre choix par défaut)
let total = 0;                // let : réassignable (compteurs, accumulateurs)
total += 1;                   // var : n'existe plus pour vous

// Fonction classique et fonction fléchée : même chose, écriture plus courte
function double(n: number): number { return n * 2; }
const triple = (n: number): number => n * 3;           // corps = une expression : return implicite
const log = (msg: string): void => { console.log(msg); }; // corps entre accolades : return explicite

// Template literal : des backticks, ${…} pour interpoler
const url = `/api/games/${port}`;
```

### Objets, déstructuration, spread

```ts
const game = { id: 1, name: 'Rocket League', genre: 'sports', teamSize: 3 };
game.name;                                 // lire une propriété (ou game['name'])
const { name, teamSize } = game;           // déstructuration : deux constantes name et teamSize
const { genre: kind = 'fps' } = game;      // renommer (kind) et valeur par défaut
const [first, second] = [10, 20];          // déstructuration de tableau

const copy = { ...game, teamSize: 5 };     // spread : copie superficielle, puis un champ surchargé
const merged = [...[1, 2], ...[3]];        // [1, 2, 3]
function sum(...nums: number[]): number {  // paramètre rest : sum(1, 2, 3)
  return nums.reduce((acc, n) => acc + n, 0);
}
const body = { name, teamSize };           // raccourci : { name } équivaut à { name: name }
```

### `?.` et `??`

```ts
const team: { name: string; coach?: { name: string } } = { name: 'Lag Busters' };
team.coach?.name;                 // undefined (pas d'exception) si coach est absent
const input: number | null = 0;
input || 10;                      // 10 : || remplace aussi 0, '' et false (piège)
input ?? 10;                      // 0  : ?? ne remplace QUE null et undefined
```

### Tableaux

```ts
const sizes = [3, 5, 1, 5];
sizes.map((n) => n * 2);              // [6, 10, 2, 10] : transformer chaque élément
sizes.filter((n) => n > 2);           // [3, 5, 5]      : garder ceux qui passent le test
sizes.find((n) => n > 4);             // 5 (ou undefined) : le premier qui convient
sizes.some((n) => n === 1);           // true : au moins un ?
sizes.every((n) => n > 0);            // true : tous ?
sizes.includes(5);                    // true
sizes.reduce((acc, n) => acc + n, 0); // 14 : accumuler (valeur initiale 0)
[...sizes].sort((a, b) => a - b);     // trié (sort modifie le tableau : copier d'abord)
sizes.length; sizes[0]; sizes.at(-1); // taille, premier, dernier
for (const n of sizes) { /* … */ }    // parcourir : for…of (pas for…in)
Object.keys(game); Object.values(game); Object.entries(game);   // un objet vu comme des tableaux
```

### JSON

```ts
const text = JSON.stringify({ id: 1, name: 'Rocket League' });   // objet → chaîne '{"id":1,"name":"Rocket League"}'
const data: unknown = JSON.parse(text);  // chaîne → valeur, de type unknown : à vérifier avant usage
```
`undefined` et les fonctions disparaissent à la sérialisation ; une `Date` devient une chaîne ISO. `res.json(obj)` appelle `JSON.stringify` pour vous.

### Modules : `import` / `export`

```ts
// src/games/game.schema.ts
export const GENRES = ['moba', 'fps'] as const;              // export nommé (plusieurs par fichier)
export interface Game { id: number; name: string }
export default function helper(): void {}                    // export par défaut (un seul par fichier)

// src/games/game.router.ts : chemin relatif + extension .js, même si le fichier est .ts (règle ESM du projet)
import helper, { GENRES, type Game } from './game.schema.js';
import { query } from '../db.js';
import express, { Router } from 'express';                   // paquet npm : ni chemin ni extension
import { readFileSync } from 'node:fs';                      // module intégré à Node
```

### Promise, async/await, try/catch

```ts
import { query } from '../db.js';

async function countGames(): Promise<number> {   // async ⇒ renvoie TOUJOURS une Promise
  const rows = await query<{ count: string }>('SELECT count(*) AS count FROM game');
  return Number(rows[0]?.count ?? 0);           // le return remplit la promesse
}

async function demo(): Promise<void> {
  const n = await countGames();      // await : attend le résultat sans bloquer le serveur
  // sans await, n serait une Promise<number>, pas un number (erreur TS2322 plus bas)
  try {
    await query('SELECT * FROM nowhere');
  } catch (err) {                    // err est de type unknown en mode strict
    if (err instanceof Error) console.error(err.message);
    throw err;                       // relancer si on ne sait pas traiter
  } finally {
    console.log(`${n} jeux`);        // toujours exécuté
  }
  // Deux requêtes en parallèle plutôt qu'à la suite
  const [games, total] = await Promise.all([query<Game>('SELECT id, name FROM game'), countGames()]);
  console.log(games.length, total);
}
```

## 2. TypeScript : les types

### Primitifs, tableaux, objets

```ts
let n: number = 3;                    // entiers et décimaux : un seul type
let s: string = 'moba';
let ok: boolean = true;
let ids: number[] = [1, 2];           // ou Array<number>
let score: [number, number] = [3, 1]; // tuple : longueur et types fixés
let obj: { id: number; name: string } = { id: 1, name: 'x' };
function nothing(): void {}           // void : ne renvoie rien
```
L'inférence fait souvent le travail : `const n = 3` est un `number`, inutile de l'écrire. Annotez les **paramètres** et le **retour** des fonctions exportées.

### `interface` et `type`

```ts
type Genre = 'moba' | 'fps' | 'fighting' | 'sports' | 'racing' | 'strategy';  // union de littéraux
interface Game {              // la forme d'un objet ; extensible avec extends
  id: number;
  name: string;
  genre: Genre;
  teamSize: number;
  description?: string;       // ? : facultatif, c'est-à-dire string | undefined
}
interface GameWithCount extends Game { playerCount: number }

type Id = number | string;                     // union
type NewGame = Omit<Game, 'id'>;               // type dérivé (voir plus bas)
type Logger = (message: string) => void;       // type de fonction
```
Pour décrire un objet, les deux conviennent. `interface` pour les objets qu'on étend, `type` pour les unions, les alias et les types dérivés.

### `null`, `undefined`, `unknown`, `any`

| | Sens | Dans le cours |
|---|---|---|
| `undefined` | « pas de valeur » : propriété absente, paramètre omis, `find` sans résultat | champs `?`, `rows[0]` |
| `null` | « vide, volontairement » | `findOne` → `null`, `team: null`, colonnes SQL NULL |
| `unknown` | « je ne sais pas encore » : vérifier avant d'utiliser | `JSON.parse`, `catch (err)`, toute donnée extérieure |
| `any` | désactive le contrôle de types | à éviter ; `req.body` est `any`, c'est pour ça qu'on valide avec zod |

En `strict`, `null` et `undefined` ne sont assignables à rien d'autre : le compilateur vous oblige à traiter le cas absent (c'est le 404 rendu obligatoire).

### Rétrécissement (narrowing)

```ts
function describe(value: unknown): string {
  if (typeof value === 'string') return value.toUpperCase();      // typeof : primitifs
  if (typeof value === 'number') return value.toFixed(1);
  if (value instanceof Date) return value.toISOString();          // instanceof : classes
  if (typeof value === 'object' && value !== null && 'name' in value) {
    return String(value.name);                                     // in : la propriété existe
  }
  return 'inconnu';
}

const game = await games.findOne(3);   // Game | null
if (!game) throw new HttpError(404, 'Game not found');
game.name;                             // ici, game est Game : le null a été éliminé par le if

type Shape = { kind: 'circle'; r: number } | { kind: 'square'; side: number };
function area(s: Shape): number {
  if (s.kind === 'circle') return Math.PI * s.r ** 2;   // === sur un littéral : union discriminée
  return s.side ** 2;
}
```

### Génériques

```ts
function first<T>(items: T[]): T | undefined {
  return items[0];
}
const g = first<Game>(games);    // g : Game | undefined
const n = first([1, 2, 3]);      // T déduit : number

// Vous en utilisez déjà : Promise<Game>, Game[] (= Array<Game>), Record<string, number>
const rows = await query<{ id: number; name: string }>('SELECT id, name FROM game');
class BaseRepository<T extends { id: number }> { /* T doit avoir un id : contrainte */ }
```

### Types utilitaires

```ts
type NewGame   = Omit<Game, 'id'>;                  // Game sans id (ce que le client envoie au POST)
type GamePatch = Partial<NewGame>;                  // tous les champs facultatifs (PATCH)
type GameRef   = Pick<Game, 'id' | 'name'>;         // seulement id et name
type Counts    = Record<Genre, number>;             // { moba: number; fps: number; … }
type Frozen    = Readonly<Game>;                    // aucune propriété modifiable
type Found     = NonNullable<Game | null>;          // Game
type Count     = Awaited<ReturnType<typeof countGames>>;   // number
```

### Classes et propriétés de paramètre

```ts
export interface FieldError { path: string; message: string }

export class HttpError extends Error {
  constructor(
    public status: number,          // propriété de paramètre : déclare ET initialise this.status
    message: string,
    public errors?: FieldError[],
  ) {
    super(message);                 // obligatoire quand on hérite
  }
}
const err = new HttpError(404, 'Game not found');
err.status;                   // 404
err instanceof HttpError;     // true

class GameRepository extends BaseRepository<Game> {
  constructor() { super('game', ['id', 'name'], 'name'); }
  private helper(): void {}   // public (défaut) / protected / private ; readonly
}
```

### `as const`, `import type`, `as`, `satisfies`

```ts
export const GENRES = ['moba', 'fps', 'fighting', 'sports', 'racing', 'strategy'] as const;
export type Genre = (typeof GENRES)[number];   // l'union des six littéraux, déduite du tableau
// sans as const, GENRES serait string[] et Genre serait string

import type { Request, Response, NextFunction } from 'express';   // n'importe que des types
import { Router, type RequestHandler } from 'express';            // mélange : type devant le nom
// Obligatoire ici (verbatimModuleSyntax) : importer un type sans « type » est l'erreur TS1484

const body = req.body as GameInput;   // assertion : « fais-moi confiance », rien n'est vérifié
// acceptable juste après validate(GameSchema) ; ailleurs, préférez zod ou le rétrécissement

const config = { port: 3000, host: 'localhost' } satisfies Record<string, string | number>;
config.port.toFixed();   // satisfies vérifie la forme SANS perdre le type précis (port reste number)
```

### Typer Express

```ts
import type { Request, Response, NextFunction, RequestHandler, ErrorRequestHandler } from 'express';
import type { z } from 'zod';

export function requireJson(req: Request, res: Response, next: NextFunction): void { /* … */ }
export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => { /* … */ };
export function validate(schema: z.ZodType): RequestHandler {
  return (req, res, next) => { /* … */ };
}
// req.params.id : string · req.query : lecture seule · req.body : any · res.locals : Record<string, any>
```

## 3. Le projet

### Commandes

| Commande | Effet |
|---|---|
| `make up`, puis `make logs` | lance l'API ; `tsx watch src/server.ts` relance le serveur à chaque sauvegarde |
| `make typecheck` | `tsc --noEmit` : vérifie TOUS les types du projet, sans rien produire ni lancer |
| `make npm c="install dayjs"` | `npm …` dans le conteneur (jamais de Node sur votre poste) |
| `make npm c="run typecheck"` | équivalent de `make typecheck` (les scripts sont dans `api/package.json`) |

`tsx` exécute votre TypeScript **sans vérifier les types** : le serveur démarre même avec des erreurs de types. Lancez `make typecheck` avant chaque commit (et au partiel). Votre éditeur montre les mêmes erreurs en direct, grâce au dossier `node_modules` monté dans `api/`.

### tsconfig.json : ce qui vous concerne

| Option | Conséquence |
|---|---|
| `strict: true` | pas de `any` implicite (TS7006) ; `null`/`undefined` traités explicitement (TS18047) |
| `noUnusedLocals`, `noUnusedParameters` | variable ou paramètre inutilisé = erreur (TS6133) : préfixez par `_` (`_req`) |
| `module: NodeNext` + `"type": "module"` | modules ES : `import`/`export`, chemins relatifs **avec `.js`** |
| `verbatimModuleSyntax` | les imports de types s'écrivent `import type` (TS1484) |
| `target: ES2022` | `??`, `?.`, `at()`, `await` au niveau d'un module disponibles |

### Lire une erreur de compilation

Format : `src/games/game.router.ts(12,9): error TS2322: Type 'string' is not assignable to type 'number'.` soit fichier, **ligne**, colonne, code, message. Lisez le message jusqu'au bout : il donne presque toujours le type attendu et le type reçu.

| Code | Message | Exemple fautif | Correction |
|---|---|---|---|
| TS2322 | `Type 'X' is not assignable to type 'Y'` | `const id: number = req.params.id;` | `const id = Number(req.params.id);` (ou `parseId`). Si `X` est `Promise<…>` : un `await` oublié |
| TS2339 | `Property 'x' does not exist on type 'Y'` | `game.nmae` ; `res.locals.query.genre` quand `query` est `unknown` | corriger la faute ; ajouter le champ à l'interface ; rétrécir, ou `as GameQuery` après `validateQuery` |
| TS2345 | `Argument of type 'X' is not assignable to parameter of type 'Y'` | `games.findOne(req.params.id)` (string) | convertir : `games.findOne(Number(req.params.id))` |
| TS7006 | `Parameter 'x' implicitly has an 'any' type` | `rows.map((r) => r.id)` après un `query()` sans `<T>` ; `function f(x) {}` | typer : `query<{ id: number }>(…)`, `(x: number)` |
| TS18047 / TS18048 / TS2531 | `'x' is possibly 'null'` / `'undefined'` / `Object is possibly 'null'` | `const g = await games.findOne(1); g.name;` | `if (!g) throw new HttpError(404, 'Game not found');` avant, ou `g?.name` |
| TS2304 | `Cannot find name 'X'` | `new HttpError(404, …)` sans import | `import { HttpError } from '../errors.js';` |
| TS6133 | `'x' is declared but its value is never read` | `(req, res, next) => { res.json(…); }` | supprimer, ou préfixer : `(_req, res)` |
| TS2307 | `Cannot find module './game.schema' or its corresponding type declarations` | `from './game.schema'` ; `from './game.schema.ts'` | extension `.js` : `from './game.schema.js'` ; pour un paquet absent : `make npm c="install …"` |
| TS1484 | `'Game' is a type and must be imported using a type-only import` | `import { Game } from './game.schema.js'` | `import type { Game } …` ou `import { games, type Game } …` |
| TS2554 | `Expected 2 arguments, but got 1` | `new HttpError(404)` | passer tous les paramètres obligatoires |

Deux réflexes : la première erreur d'une cascade est souvent la seule vraie (un import manquant en produit dix) ; ne corrigez jamais une erreur avec `any` ou `as` : vous cachez le problème, il reviendra à l'exécution.
