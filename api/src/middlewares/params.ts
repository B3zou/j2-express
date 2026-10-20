// req.params.id est une chaîne ("3", mais aussi "abc", "1.0", "99999999999") : on en fait un entier
// valide pour PostgreSQL, sinon 404. Au J0, c'était Requirement::DIGITS sur la route.
import { HttpError } from '../errors.js';

export const MAX_ID = 2_147_483_647; // integer PostgreSQL (4 octets)

export function parseId(value: unknown, what: string): number {
  if (typeof value !== 'string' || !/^[1-9]\d*$/.test(value)) throw new HttpError(404, `${what} not found`);
  const id = Number(value);
  if (id > MAX_ID) throw new HttpError(404, `${what} not found`);
  return id;
}
