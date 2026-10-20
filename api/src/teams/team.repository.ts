// L'accès aux données de Team. Hier : TeamRepository (Doctrine).
import { query } from '../db.js';
import { BaseRepository } from '../repository.js';
import { players } from '../players/player.repository.js';
import type { Team, TeamWithPlayers } from './team.schema.js';

class TeamRepository extends BaseRepository<Team> {
  constructor() {
    super('team', ['id', 'name', 'tag', 'country'], 'name');
  }

  /** Une équipe avec ses joueurs (deux requêtes), ou null. */
  async findOneWithPlayers(id: number): Promise<TeamWithPlayers | null> {
    const team = await this.findOne(id);
    if (!team) return null;
    return { ...team, players: await players.findByTeam(id) };
  }

  /** Le niveau moyen d'une équipe (entier), ou null si elle n'a aucun joueur. */
  async ratingOf(teamId: number): Promise<number | null> {
    const [row] = await query<{ rating: number | null }>(
      `SELECT round(avg(rating))::int AS rating FROM player WHERE team_id = $1`,
      [teamId],
    );
    return row?.rating ?? null;
  }

  /** Toutes les équipes, ou celles d'un pays, triées par nom. */
  findByCountry(country?: string): Promise<Team[]> {
    if (!country) return query<Team>(`${this.select} ORDER BY name`);
    return query<Team>(`${this.select} WHERE country = $1 ORDER BY name`, [country]);
  }
}

export const teams = new TeamRepository();
