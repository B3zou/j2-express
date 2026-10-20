// Les types et les schémas de validation de Player. Hier : l'entité Player + le DTO PlayerInput.
import { z } from 'zod';

/** Une ligne de la table player (ce que le repository lit et écrit). */
export interface Player {
  id: number;
  nickname: string;
  country: string;
  role: string | null;
  rating: number;
  birthDate: string | null; // AAAA-MM-JJ en écriture ; donnée personnelle, jamais renvoyée par l'API
  teamId: number | null;
}

/** Ce que l'API renvoie : l'équipe imbriquée (id, name, tag), pas de date de naissance. */
export interface PlayerView {
  id: number;
  nickname: string;
  country: string;
  role: string | null;
  rating: number;
  team: { id: number; name: string; tag: string } | null;
}

/** Un joueur vu depuis son équipe (GET /api/teams/:id). */
export interface PlayerSummary {
  id: number;
  nickname: string;
  role: string | null;
  rating: number;
}

const thirteenYearsAgo = new Date();
thirteenYearsAgo.setFullYear(thirteenYearsAgo.getFullYear() - 13);

// Ce que le client a le droit d'envoyer (POST). Les champs absents prennent la valeur par défaut de la base.
export const PlayerSchema = z.object({
  nickname: z.string().trim().min(2).max(30),
  country: z.string().regex(/^[A-Z]{2}$/, 'must be a 2-letter uppercase country code'),
  role: z.string().trim().max(30).nullish(),
  rating: z.number().int().min(0).max(3000).optional(), // défaut : 1000 (schema.sql)
  birthDate: z.iso
    .date()
    .refine((date) => new Date(date) <= thirteenYearsAgo, 'must be at least 13 years old')
    .nullish(),
  teamId: z.number().int().positive().nullish(), // null = agent libre
});
export type PlayerInput = z.infer<typeof PlayerSchema>;
export const PlayerPatchSchema = PlayerSchema.partial();

// ?page=2&limit=5&country=fr&teamId=3&q=zer : les paramètres de requête sont des chaînes → z.coerce
export const PlayerSearchSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(10),
  country: z
    .string()
    .regex(/^[A-Za-z]{2}$/)
    .transform((s) => s.toUpperCase())
    .optional(),
  teamId: z.coerce.number().int().positive().optional(),
  q: z.string().trim().min(1).optional(),
});
export type PlayerSearch = z.infer<typeof PlayerSearchSchema>;

// ?limit=3&country=is pour le classement
export const TopQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(10),
  country: z
    .string()
    .regex(/^[A-Za-z]{2}$/)
    .transform((s) => s.toUpperCase())
    .optional(),
});
export type TopQuery = z.infer<typeof TopQuerySchema>;
