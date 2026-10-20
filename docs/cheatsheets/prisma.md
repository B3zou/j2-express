# Antisèche Prisma (et les autres ORM)

Un ORM (*Object-Relational Mapper*) fait le lien entre vos objets et vos tables : il génère le SQL des cas
courants à partir d'une description du schéma. Prisma est le plus répandu dans l'écosystème TypeScript.
Référence : https://www.prisma.io/docs · Branche de démo : `demo-prisma`.

## Les trois pièces

| Pièce | Fichier | Rôle |
|---|---|---|
| le **schéma** | `prisma/schema.prisma` | un `model` par table, les champs, les relations, les `@map` vers les noms SQL |
| le **client** | `src/generated/prisma/` (généré, gitignoré) | une classe `PrismaClient` typée d'après le schéma : `prisma.team.findMany(…)` |
| la **CLI** | `make prisma c="…"` | `db pull` (introspecter une base), `generate` (produire le client), `migrate dev` (projet neuf), `studio` |

```ts
// src/prisma.ts : UN client pour tout le projet (Prisma 7 : via un adaptateur, ici pg)
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from './generated/prisma/client.js';
export const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });
```

## Le schéma

```prisma
model Team {
  id      Int      @id @default(autoincrement())
  name    String   @unique @db.VarChar(50)
  country String   @db.Char(2)
  players Player[]                       // le côté « un » d'une relation 1-n

  @@map("team")                          // le nom de la table SQL
}

model Player {
  id     Int   @id @default(autoincrement())
  teamId Int?  @map("team_id")           // la clé étrangère, nullable
  team   Team? @relation(fields: [teamId], references: [id], onDelete: SetNull)
  @@map("player")
}
```

`?` = nullable, `@unique`, `@default`, `@map("colonne")`, `@@map("table")`, `@relation(fields, references,
onDelete)`. Les contraintes `CHECK` ne sont pas modélisées : la base et zod s'en chargent.

## Les requêtes courantes

```ts
prisma.team.findMany({ where: { country: 'FR' }, orderBy: { name: 'asc' }, skip: 10, take: 10 });
prisma.team.findUnique({ where: { id } });                              // par clé unique ; null si absent
prisma.team.findFirst({ where: { tag: { startsWith: 'N' } } });
prisma.team.findUnique({ where: { id }, include: { players: true } });  // la relation, chargée
prisma.player.findMany({ select: { id: true, nickname: true, team: { select: { tag: true } } } }); // la forme exacte
prisma.player.findMany({ where: { nickname: { contains: q, mode: 'insensitive' } } });            // ILIKE %q%
prisma.player.count({ where });
prisma.player.aggregate({ where: { teamId }, _avg: { rating: true } });  // { _avg: { rating: 2350 } }
prisma.team.create({ data: { name, tag, country } });                    // renvoie la ligne créée
prisma.team.update({ where: { id }, data: { name } });                   // lève P2025 si l'id n'existe pas
prisma.match.updateMany({ where: { id, playedAt: null }, data });        // renvoie { count }, ne lève pas
prisma.team.delete({ where: { id } });                                   // lève P2025 si absent
prisma.team.deleteMany({ where: { id } });                               // { count } : 0 n'est pas une erreur
prisma.$transaction([prisma.player.findMany(args), prisma.player.count({ where })]); // deux requêtes, une transaction
prisma.$queryRaw`SELECT count(*) OVER () …`;                              // la porte de sortie vers le SQL
```

Les clés `undefined` dans `data` sont **ignorées** (pratique pour un PATCH) ; `null` vide le champ. Les `where`
se composent : `{ AND: […], OR: […], NOT: … }`, `{ rating: { gte: 2000 } }`, `{ playedAt: { not: null } }`.

## Les erreurs

```ts
import { Prisma } from './generated/prisma/client.js';
if (err instanceof Prisma.PrismaClientKnownRequestError) switch (err.code) { … }
```

| Code | Sens | Hier (pg) | Réponse |
|---|---|---|---|
| `P2002` | contrainte UNIQUE | `23505` | 409 Conflict |
| `P2003` | clé étrangère | `23503` | 422 (« does not exist ») |
| `P2025` | ligne introuvable (`update`, `delete`) | — | 404 |
| `P2020` | valeur hors type (id > 2 147 483 647) | `22003` | 422 |

Le nom de la contrainte SQL (« team_name_key ») se lit dans `err.meta` : voir `translatePrismaError` dans
`src/prisma.ts` sur la branche.

## La CLI, dans Docker

```bash
make prisma c="db pull"      # base → schema.prisma (introspection : quand la base existe déjà)
make prisma c="generate"     # schema.prisma → client TypeScript (relancé automatiquement au démarrage si le schéma a changé)
make prisma c="validate"     # le schéma est-il correct ?
make prisma-studio           # l'explorateur de données : http://localhost:5555
# sur un projet neuf : make prisma c="migrate dev --name init"  (schéma → SQL de migration → base)
```

## Les autres ORM, pour les reconnaître

| | Prisma | Sequelize | TypeORM | Drizzle |
|---|---|---|---|---|
| le schéma | fichier `.prisma` | classes `Model.init()` / `sequelize.define` | classes avec décorateurs `@Entity() @Column()` | objets `pgTable(…)` en TS |
| lire | `prisma.team.findMany({ where, orderBy, take })` | `Team.findAll({ where, order, limit })` | `repo.find({ where, order, take })` | `db.select().from(team).where(…)` |
| la relation | `include: { players: true }` | `include: [Player]` | `relations: ['players']` | `with: { players: true }` |
| créer | `create({ data })` | `Team.create(data)` | `repo.save(repo.create(data))` | `db.insert(team).values(data)` |
| les erreurs | `P2002`… | `UniqueConstraintError` | `QueryFailedError` + `code` pg | erreur pg brute |
| typage | généré, très fort | faible | moyen | très fort |

Même structure partout : **un objet qui décrit la requête**, une méthode par verbe, une façon de charger les
relations, une famille d'erreurs. Et toujours une porte vers le SQL brut (`$queryRaw`, `sequelize.query`,
`repo.query`, `sql\`…\``) pour ce que l'ORM n'exprime pas bien.
