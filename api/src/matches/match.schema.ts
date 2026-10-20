// Les types et les schémas de validation de Match (TP partie 1).
import { z } from 'zod';

/** Une ligne de la table match. */
export interface Match {
  id: number;
  teamAId: number;
  teamBId: number;
  scoreA: number | null;
  scoreB: number | null;
  winnerId: number | null;
  playedAt: Date | null;
}

export type MatchStatus = 'scheduled' | 'played';

/** Ce que l'API renvoie. */
export interface MatchView {
  id: number;
  status: MatchStatus;
  teamA: { id: number; name: string; tag: string };
  teamB: { id: number; name: string; tag: string };
  score: [number, number] | null;
  winner: string | null; // le tag
  playedAt: Date | null;
}

export const MatchSchema = z
  .object({
    teamAId: z.number().int().positive(),
    teamBId: z.number().int().positive(),
  })
  .refine((m) => m.teamAId !== m.teamBId, { path: ['teamBId'], message: 'must differ from teamAId' });
export type MatchInput = z.infer<typeof MatchSchema>;

export const MatchQuerySchema = z.object({
  status: z.enum(['scheduled', 'played']).optional(),
});
export type MatchQuery = z.infer<typeof MatchQuerySchema>;

// ?seed=42 : une graine pour un tirage reproductible (play et versus)
export const SeedQuerySchema = z.object({
  seed: z.coerce.number().int().optional(),
});
export type SeedQuery = z.infer<typeof SeedQuerySchema>;
