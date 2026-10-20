// BaseRepository<T> : le CRUD générique, écrit une fois pour toutes les ressources.
// Tout ce qui est spécifique (filtres, jointures, classements) s'écrit à la main, en SQL,
// dans le repository de chaque ressource (voir games/game.repository.ts).
import { query } from './db.js';

/** "teamSize" → "team_size" : les propriétés sont en camelCase, les colonnes en snake_case. */
export function toSnakeCase(key: string): string {
  return key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
}

/** Les paires [clé, valeur] dont la valeur n'est pas undefined (une clé absente n'est pas une colonne à écrire). */
function definedEntries(data: object): [string, unknown][] {
  return Object.entries(data).filter(([, value]) => value !== undefined);
}

export class BaseRepository<T extends { id: number }> {
  /**
   * @param table    le nom de la table (jamais une valeur venue du client)
   * @param columns  les colonnes lues, avec leurs alias camelCase : ['id', 'name', 'team_size AS "teamSize"']
   * @param orderBy  la colonne de tri par défaut des listes
   */
  constructor(
    protected readonly table: string,
    protected readonly columns: string[],
    protected readonly orderBy = 'id',
  ) {}

  /** « SELECT col1, col2 FROM table » : le début de toutes les requêtes de lecture. */
  protected get select(): string {
    return `SELECT ${this.columns.join(', ')} FROM ${this.table}`;
  }

  /** La page demandée (10 éléments par défaut), triée. */
  findAll(page = 1, limit = 10): Promise<T[]> {
    const offset = (page - 1) * limit;
    return query<T>(`${this.select} ORDER BY ${this.orderBy} LIMIT $1 OFFSET $2`, [limit, offset]);
  }

  async count(): Promise<number> {
    const [row] = await query<{ count: string }>(`SELECT count(*) AS count FROM ${this.table}`);
    return Number(row?.count ?? 0);
  }

  /** Un élément par son id, ou null : c'est le routeur qui décide du 404. */
  async findOne(id: number): Promise<T | null> {
    const [row] = await query<T>(`${this.select} WHERE id = $1`, [id]);
    return row ?? null;
  }

  /** INSERT à partir d'un objet déjà validé (clés connues) ; renvoie la ligne créée.
   *  Une clé absente ou undefined n'est pas insérée : la base applique sa valeur par défaut (ou NULL). */
  async insert(data: Partial<Omit<T, 'id'>>): Promise<T> {
    const entries = definedEntries(data);
    const columns = entries.map(([key]) => toSnakeCase(key)).join(', ');
    const placeholders = entries.map((_, i) => `$${i + 1}`).join(', ');
    const [row] = await query<T>(
      `INSERT INTO ${this.table} (${columns}) VALUES (${placeholders}) RETURNING ${this.columns.join(', ')}`,
      entries.map(([, value]) => value),
    );
    return row as T;
  }

  /** UPDATE partiel (PATCH) : seules les clés présentes changent (null est une valeur : « vider le champ »).
   *  Renvoie null si l'id n'existe pas. */
  async update(id: number, data: Partial<Omit<T, 'id'>>): Promise<T | null> {
    const entries = definedEntries(data);
    if (entries.length === 0) return this.findOne(id); // rien à changer : pas une erreur
    const assignments = entries.map(([key], i) => `${toSnakeCase(key)} = $${i + 2}`).join(', ');
    const [row] = await query<T>(
      `UPDATE ${this.table} SET ${assignments} WHERE id = $1 RETURNING ${this.columns.join(', ')}`,
      [id, ...entries.map(([, value]) => value)],
    );
    return row ?? null;
  }

  /** true si une ligne a été supprimée, false si l'id n'existait pas. */
  async delete(id: number): Promise<boolean> {
    const rows = await query<{ id: number }>(`DELETE FROM ${this.table} WHERE id = $1 RETURNING id`, [id]);
    return rows.length > 0;
  }
}
