// L'accès aux données de Game : le CRUD vient de BaseRepository, le reste est du SQL écrit à la main.
// Hier : GameRepository (Doctrine) et ses méthodes find*, plus une requête sur mesure.
import { query } from '../db.js';
import { BaseRepository } from '../repository.js';
import type { Game, Genre } from './game.schema.js';

class GameRepository extends BaseRepository<Game> {
  constructor() {
    super('game', ['id', 'name', 'genre', 'team_size AS "teamSize"'], 'name');
  }

  findByGenre(genre: Genre): Promise<Game[]> {
    return query<Game>(
      `SELECT id, name, genre,
              team_size AS "teamSize"
         FROM game
        WHERE genre = $1
        ORDER BY name`,
      [genre],
    );
  }
}

export const games = new GameRepository();
