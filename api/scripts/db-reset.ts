// Recrée la base désignée par DATABASE_URL : supprime le schéma, rejoue db/schema.sql
// puis db/seed.sql (sauf avec --no-seed). Utilisé par « make db-reset » et par « make test ».
// Vous n'avez pas à modifier ce fichier.
import { readFileSync } from 'node:fs';
import { Client } from 'pg';

const url = new URL(process.env.DATABASE_URL ?? 'postgres://app:app@database:5432/app');
const database = url.pathname.slice(1);
const withSeed = !process.argv.includes('--no-seed');

async function ensureDatabase(): Promise<void> {
  const admin = new Client({ connectionString: new URL('/app', url).toString() });
  await admin.connect();
  try {
    await admin.query(`CREATE DATABASE "${database}"`);
  } catch (err) {
    if ((err as { code?: string }).code !== '42P04') throw err; // 42P04 : la base existe déjà
  } finally {
    await admin.end();
  }
}

async function reset(): Promise<void> {
  if (database !== 'app') await ensureDatabase();
  const client = new Client({ connectionString: url.toString() });
  await client.connect();
  try {
    await client.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
    await client.query(readFileSync(new URL('../db/schema.sql', import.meta.url), 'utf8'));
    if (withSeed) await client.query(readFileSync(new URL('../db/seed.sql', import.meta.url), 'utf8'));
  } finally {
    await client.end();
  }
  console.log(`✔ Base « ${database} » recréée${withSeed ? ', données de démo chargées (identifiants 1, 2, 3…)' : ' (vide)'}`);
}

reset().catch((err) => {
  console.error(err);
  process.exit(1);
});
