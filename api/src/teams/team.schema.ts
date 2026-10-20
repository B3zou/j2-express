// Les types et les schémas de validation de Team. Hier : l'entité Team + ses #[Assert\…].
import { z } from 'zod';
import type { PlayerSummary } from '../players/player.schema.js';

export interface Team {
  id: number;
  name: string;
  tag: string;
  country: string;
}

/** GET /api/teams/:id : l'équipe et ses joueurs */
export interface TeamWithPlayers extends Team {
  players: PlayerSummary[];
}

// Ce que le client a le droit d'envoyer (POST). Hier : NotBlank, Length, Regex, Country.
export const TeamSchema = z.object({
  name: z.string().trim().min(2).max(50),
  tag: z.string().regex(/^[A-Z0-9]{2,5}$/, 'must be 2 to 5 uppercase letters or digits'),
  country: z.string().regex(/^[A-Z]{2}$/, 'must be a 2-letter uppercase country code'),
});
export type TeamInput = z.infer<typeof TeamSchema>;
export const TeamPatchSchema = TeamSchema.partial(); // PATCH : tous les champs facultatifs

// ?country=be : deux lettres, mises en majuscules
export const TeamQuerySchema = z.object({
  country: z
    .string()
    .regex(/^[A-Za-z]{2}$/)
    .transform((s) => s.toUpperCase())
    .optional(),
});
export type TeamQuery = z.infer<typeof TeamQuerySchema>;
