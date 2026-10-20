// L'accès à la table "user" (entre guillemets : user est un mot réservé en SQL).
// Le CRUD vient de BaseRepository ; findByEmail est la seule requête sur mesure. Rien à changer ici.
import { query } from '../db.js';
import { BaseRepository } from '../repository.js';
import type { User } from './user.schema.js';

class UserRepository extends BaseRepository<User> {
  constructor() {
    super('"user"', ['id', 'email', 'password', 'created_at AS "createdAt"'], 'email');
  }

  /** L'utilisateur qui a cet email (déjà en minuscules, merci zod), ou null. */
  async findByEmail(email: string): Promise<User | null> {
    const [row] = await query<User>(`${this.select} WHERE email = $1`, [email]);
    return row ?? null;
  }
}

export const users = new UserRepository();
