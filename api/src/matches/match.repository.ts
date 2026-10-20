// L'accès aux données de Match : la vue (deux jointures sur team) est écrite à la main.
import { query } from '../db.js';
import { BaseRepository } from '../repository.js';
import type { Match, MatchStatus, MatchView } from './match.schema.js';
import type { MatchResult } from './simulator.js';

const VIEW = `
  SELECT m.id,
         CASE WHEN m.played_at IS NULL THEN 'scheduled' ELSE 'played' END AS status,
         json_build_object('id', a.id, 'name', a.name, 'tag', a.tag) AS "teamA",
         json_build_object('id', b.id, 'name', b.name, 'tag', b.tag) AS "teamB",
         CASE WHEN m.played_at IS NULL THEN NULL ELSE json_build_array(m.score_a, m.score_b) END AS score,
         w.tag AS winner,
         m.played_at AS "playedAt"
    FROM match m
    JOIN team a ON a.id = m.team_a_id
    JOIN team b ON b.id = m.team_b_id
    LEFT JOIN team w ON w.id = m.winner_id`;

class MatchRepository extends BaseRepository<Match> {
  constructor() {
    super(
      'match',
      ['id', 'team_a_id AS "teamAId"', 'team_b_id AS "teamBId"', 'score_a AS "scoreA"', 'score_b AS "scoreB"', 'winner_id AS "winnerId"', 'played_at AS "playedAt"'],
      'id',
    );
  }

  async findView(id: number): Promise<MatchView | null> {
    const [row] = await query<MatchView>(`${VIEW} WHERE m.id = $1`, [id]);
    return row ?? null;
  }

  /** Tous les matchs, ou ceux d'un statut, du plus ancien au plus récent. */
  findByStatus(status?: MatchStatus): Promise<MatchView[]> {
    if (!status) return query<MatchView>(`${VIEW} ORDER BY m.id`);
    const condition = status === 'played' ? 'm.played_at IS NOT NULL' : 'm.played_at IS NULL';
    return query<MatchView>(`${VIEW} WHERE ${condition} ORDER BY m.id`);
  }

  /** Enregistre le résultat d'un match pas encore joué ; false s'il l'était déjà (ou n'existe pas). */
  async recordResult(id: number, result: MatchResult): Promise<boolean> {
    const winnerId = result.winner === result.teamA.tag ? result.teamA.id : result.teamB.id;
    const rows = await query<{ id: number }>(
      `UPDATE match
          SET score_a = $2, score_b = $3, winner_id = $4, played_at = now()
        WHERE id = $1 AND played_at IS NULL
        RETURNING id`,
      [id, result.score[0], result.score[1], winnerId],
    );
    return rows.length > 0;
  }
}

export const matches = new MatchRepository();
