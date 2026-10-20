# J2 · Démo — Et avec un vrai ORM ? Le même projet avec Prisma

> Antisèche : [Prisma](cheatsheets/prisma.md). Branche : `demo-prisma` (`git fetch upstream && git checkout
> upstream/demo-prisma`, puis `make install`). Pas un TD : un document à suivre pendant la démo, et à relire.

## Pourquoi ce détour

Hier, vous avez écrit à la main ce que Symfony faisait pour vous au J0 : un `BaseRepository<T>` avec `findAll`,
`findOne`, `insert`, `update`, `delete`, et du SQL pour tout le reste. Beaucoup d'entre vous ont trouvé le
découpage schéma / repository / routeur lourd pour ce qu'il fait. C'est une bonne intuition : **ce découpage est
exactement ce qu'un ORM génère**. Le repository que vous avez tapé, Prisma le fabrique à partir d'un fichier de
schéma, typé, pour toutes les tables, avec les relations.

Au partiel, le sujet peut imposer un ORM (Prisma, Sequelize, TypeORM, Drizzle…). Cette démo vous donne les
repères pour en reconnaître un et lire sa documentation vite.

## 1. Le schéma : `prisma/schema.prisma` en face de `db/schema.sql`

```prisma
model Player {
  id        Int       @id @default(autoincrement())
  nickname  String    @unique @db.VarChar(30)
  country   String    @db.Char(2)
  role      String?   @db.VarChar(30)
  rating    Int       @default(1000)
  birthDate DateTime? @map("birth_date") @db.Date
  teamId    Int?      @map("team_id")
  team      Team?     @relation(fields: [teamId], references: [id], onDelete: SetNull)

  @@map("player")
}
```

Un modèle par table, un champ par colonne, les relations déclarées. `@map` relie le camelCase du code au
snake_case de la base : fini les alias `birth_date AS "birthDate"`. Ce fichier n'a pas été tapé : il vient de
**l'introspection** de la base existante :

```bash
make prisma c="db pull"      # lit la base, écrit schema.prisma
make prisma c="generate"     # produit le client TypeScript dans src/generated/prisma (gitignoré)
```

Ce que Prisma **ne** modélise **pas** : les contraintes `CHECK` (`rating BETWEEN 0 AND 3000`, `team_a_id <>
team_b_id`). Elles restent dans la base et dans zod. Un ORM ne remplace pas la validation.

## 2. Le client : ce que le repository devient

| Hier (pg, à la main) | Aujourd'hui (Prisma) |
|---|---|
| `query<Team>('SELECT … FROM team WHERE id = $1', [id])` | `prisma.team.findUnique({ where: { id } })` |
| `findOneWithPlayers` : deux requêtes, un objet assemblé | `prisma.team.findUnique({ where: { id }, include: { players: { select: {…}, orderBy: {…} } } })` |
| `INSERT … RETURNING` généré par `BaseRepository.insert` | `prisma.team.create({ data })` |
| `UPDATE … SET a = $2, b = $3 … RETURNING` | `prisma.team.update({ where: { id }, data })` |
| `DELETE … RETURNING id`, puis `rows.length > 0` | `prisma.team.deleteMany({ where: { id } })` → `count` |
| `ILIKE $1` avec `%q%` dans la valeur | `{ nickname: { contains: q, mode: 'insensitive' } }` |
| `count(*) OVER ()` dans la même requête | `prisma.$transaction([findMany(…), count(…)])` : deux requêtes |
| `round(avg(rating))::int` | `prisma.player.aggregate({ where: { teamId }, _avg: { rating: true } })` |
| `json_build_object('id', t.id, …) AS team` | `select: { …, team: { select: { id: true, name: true, tag: true } } }` |

Le résultat est **typé** : `findUnique` avec un `select` renvoie exactement la forme demandée, et une faute de frappe
dans un nom de champ est une erreur de compilation, pas un `undefined` à l'exécution comme hier avec `query<T>`.

Regardez `api/src/players/player.repository.ts` sur la branche : la recherche paginée, le classement, la vue avec
l'équipe imbriquée, en 60 lignes sans une ligne de SQL. Puis `git diff solution demo-prisma -- api/src` : les
routeurs n'ont **pas changé**. Le repository était la bonne frontière.

## 3. Les erreurs : `translatePrismaError` en face de `translatePgError`

Hier : le code PostgreSQL `23505` → 409. Aujourd'hui : le code Prisma `P2002` → 409, `P2003` (clé étrangère) →
422, `P2025` (ligne introuvable) → 404. Même idée, même place (`errorHandler.ts`), vocabulaire différent. Chaque
ORM a sa famille d'erreurs : c'est la première chose à chercher dans sa documentation.

## 4. Les outils : `make prisma-studio`

Un explorateur de données dans le navigateur (http://localhost:5555) : les tables, les relations, l'édition. Ce
que `make db-shell` fait en ligne de commande. (Sur un projet neuf, Prisma gère aussi les **migrations** :
`prisma migrate dev` compare le schéma à la base et écrit le SQL de différence. Ici, la base existait avant :
`schema.sql` reste la référence et on a introspecté.)

## 5. Le même besoin, quatre écritures

« Les 3 meilleurs joueurs islandais » :

```ts
// pg (hier)
query<PlayerView>(`${VIEW} WHERE p.country = $1 ORDER BY p.rating DESC LIMIT $2`, ['IS', 3]);

// Prisma
prisma.player.findMany({ where: { country: 'IS' }, orderBy: { rating: 'desc' }, take: 3, include: { team: true } });

// Sequelize
Player.findAll({ where: { country: 'IS' }, order: [['rating', 'DESC']], limit: 3, include: [Team] });

// TypeORM
playerRepository.find({ where: { country: 'IS' }, order: { rating: 'DESC' }, take: 3, relations: ['team'] });
```

Les mots changent (`take` / `limit`, `include` / `relations`), la forme est la même : **un objet qui décrit la
requête**. Si le partiel impose un ORM que vous ne connaissez pas : cherchez dans sa doc « find », « where »,
« order », « limit », « include/relations », « create », « update », « delete », et sa famille d'erreurs. Tout le
reste (routeurs, validation, erreurs HTTP, tests) est ce que vous savez déjà faire.

## 6. Quand ne pas utiliser d'ORM

- Une requête de **reporting** (classements composés, fenêtres `OVER ()`, `json_build_object`) : en SQL, elle tient
  en dix lignes et s'exécute en une fois ; en ORM, elle devient deux ou trois requêtes ou un `$queryRaw`… qui est du
  SQL. Tous les ORM ont une porte de sortie vers le SQL brut ; sachez où elle est.
- Un projet **minuscule** (trois tables, un week-end) : le temps d'apprendre l'ORM dépasse le temps gagné.
- Et à l'inverse : un projet avec vingt tables et des relations partout, où écrire `BaseRepository` et vingt
  repositories à la main est une perte de temps et une source de bugs. C'est là que l'ORM paie.

Ce que vous emportez : le découpage **routeur / validation / accès aux données** est le même avec ou sans ORM. Vous
l'avez écrit à la main une fois, vous savez ce qu'il y a dedans. C'est ce qui vous permettra d'en lire n'importe
lequel.
