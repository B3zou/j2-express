// L'accès aux données de Player. Le CRUD vient de BaseRepository ; la vue avec l'équipe imbriquée
// est une requête écrite à la main (LEFT JOIN + json_build_object).
import { query } from '../db.js';
import { BaseRepository } from '../repository.js';
import type { Player, PlayerSearch, PlayerSummary, PlayerView, TopQuery } from './player.schema.js';

// La « vue » d'un joueur : sans birth_date, avec son équipe réduite à { id, name, tag } (ou null)
const VIEW_COLUMNS = `p.id, p.nickname, p.country, p.role, p.rating,
         CASE WHEN t.id IS NULL THEN NULL
              ELSE json_build_object('id', t.id, 'name', t.name, 'tag', t.tag) END AS team`;
const VIEW_FROM = `FROM player p LEFT JOIN team t ON t.id = p.team_id`;
const VIEW = `SELECT ${VIEW_COLUMNS} ${VIEW_FROM}`;

class PlayerRepository extends BaseRepository<Player> {
  constructor() {
    super('player', ['id', 'nickname', 'country', 'role', 'rating', 'birth_date AS "birthDate"', 'team_id AS "teamId"'], 'nickname');
  }

  /** La vue d'un joueur, ou null. */
  async findView(id: number): Promise<PlayerView | null> {
    const [row] = await query<PlayerView>(`${VIEW} WHERE p.id = $1`, [id]);
    return row ?? null;
  }

  /**
   * Recherche paginée : les filtres présents ajoutent une condition ($n) ; le total est compté
   * par la même requête (count(*) OVER ()), avant LIMIT/OFFSET.
   */
  async search({ page, limit, country, teamId, q }: PlayerSearch): Promise<{ items: PlayerView[]; total: number }> {
    const conditions: string[] = [];
    const values: unknown[] = [];
    if (country) {
      values.push(country);
      conditions.push(`p.country = $${values.length}`);
    }
    if (teamId) {
      values.push(teamId);
      conditions.push(`p.team_id = $${values.length}`);
    }
    if (q) {
      values.push(`%${q}%`); // les % vont dans la VALEUR, jamais dans le texte SQL
      conditions.push(`p.nickname ILIKE $${values.length}`);
    }
    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    values.push(limit, (page - 1) * limit);
    const rows = await query<PlayerView & { total: string }>(
      `SELECT count(*) OVER () AS total, ${VIEW_COLUMNS}
       ${VIEW_FROM} ${where}
       ORDER BY p.nickname
       LIMIT $${values.length - 1} OFFSET $${values.length}`,
      values,
    );
    const total = rows.length ? Number(rows[0]!.total) : await this.countWhere(where, values.slice(0, -2));
    return { items: rows.map(({ total: _total, ...view }) => view), total };
  }

  /** Le total quand la page est vide (au-delà de la dernière page). */
  private async countWhere(where: string, values: unknown[]): Promise<number> {
    const [row] = await query<{ count: string }>(`SELECT count(*) AS count FROM player p ${where}`, values);
    return Number(row?.count ?? 0);
  }

  /** Les meilleurs joueurs (rating décroissant), éventuellement d'un pays. */
  findTop({ limit, country }: TopQuery): Promise<PlayerView[]> {
    return query<PlayerView>(
      `${VIEW}
       WHERE $1::text IS NULL OR p.country = $1
       ORDER BY p.rating DESC, p.nickname
       LIMIT $2`,
      [country ?? null, limit],
    );
  }

  /** Les joueurs d'une équipe, pour GET /api/teams/:id. */
  findByTeam(teamId: number): Promise<PlayerSummary[]> {
    return query<PlayerSummary>(
      `SELECT id, nickname, role, rating FROM player WHERE team_id = $1 ORDER BY nickname`,
      [teamId],
    );
  }
}

export const players = new PlayerRepository();
