// Accès à PostgreSQL : un pool de connexions et une fonction query<T>() pour tout le projet.
import { Pool } from 'pg';
import { HttpError } from './errors.js';

export const pool = new Pool({ connectionString: process.env.DATABASE_URL });

/**
 * Exécute une requête SQL paramétrée ($1, $2…) et renvoie les lignes.
 * Le type T décrit la forme d'une ligne : c'est une promesse faite au compilateur, pas une
 * vérification (si la requête renvoie team_size, la propriété teamSize sera undefined :
 * d'où les alias SQL `team_size AS "teamSize"`).
 */
export async function query<T>(text: string, values: unknown[] = []): Promise<T[]> {
  const result = await pool.query<T & Record<string, unknown>>(text, values);
  return result.rows;
}

interface PgError {
  code?: string;
  detail?: string;
  constraint?: string;
  column?: string;
}

/** "team_id" → "teamId" */
function toCamelCase(column: string): string {
  return column.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase());
}

/** Le nom du champ concerné par une erreur de contrainte, d'après le détail de PostgreSQL. */
function fieldOf(err: PgError): string {
  const match = err.detail?.match(/Key \((\w+)\)/); // « Key (name)=(Valorant) already exists. »
  const column = match?.[1] ?? err.column ?? err.constraint?.replace(/^\w+?_(.+)_(key|fkey|check)$/, '$1') ?? 'unknown';
  return toCamelCase(column);
}

/**
 * Traduit une erreur PostgreSQL en HttpError, ou renvoie null si ce n'en est pas une.
 * 23505 : contrainte UNIQUE (nom déjà pris) → 409 Conflict
 * 23503 : clé étrangère (l'équipe n'existe pas) → 422
 * 23514 : contrainte CHECK (valeur hors bornes) → 422
 */
export function translatePgError(err: unknown): HttpError | null {
  const pg = err as PgError;
  switch (pg?.code) {
    case '23505':
      return new HttpError(409, 'Conflict', [{ path: fieldOf(pg), message: 'already exists' }]);
    case '23503':
      return new HttpError(422, 'Validation Failed', [{ path: fieldOf(pg), message: 'does not exist' }]);
    case '23514':
      return new HttpError(422, 'Validation Failed', [{ path: fieldOf(pg), message: 'invalid value' }]);
    case '22003': // numeric_value_out_of_range : un id au-delà de 2 147 483 647 (integer)
      return new HttpError(422, 'Validation Failed', [{ path: fieldOf(pg), message: 'value out of range' }]);
    default:
      return null;
  }
}
