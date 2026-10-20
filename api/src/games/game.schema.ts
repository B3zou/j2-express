// Les types et les schémas de validation de Game. Hier : l'entité Game + ses #[Assert\…].
import { z } from 'zod';

export const GENRES = ['moba', 'fps', 'fighting', 'sports', 'racing', 'strategy'] as const;
export type Genre = (typeof GENRES)[number]; // 'moba' | 'fps' | 'fighting' | 'sports' | 'racing' | 'strategy'

export interface Game {
  id: number;
  name: string;
  genre: Genre;
  teamSize: number;
}

export type NewGame = Omit<Game, 'id'>; // le client ne choisit jamais l'id

// Ce que le client a le droit d'envoyer, vérifié à l'exécution (les types TypeScript n'existent plus).
export const GameSchema = z.object({
  name: z.string().trim().min(1).max(100),
  genre: z.enum(GENRES),
  teamSize: z.number().int().min(1).max(10),
});
export type GameInput = z.infer<typeof GameSchema>; // le type, déduit du schéma
export const GamePatchSchema = GameSchema.partial(); // PATCH : tous les champs facultatifs

export const GameQuerySchema = z.object({
  genre: z.enum(GENRES).optional(),
});
export type GameQuery = z.infer<typeof GameQuerySchema>;
