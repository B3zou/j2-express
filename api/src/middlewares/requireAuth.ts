// Le middleware qui protège une route : il exige un jeton valide dans l'en-tête Authorization.
// Il se pose PAR ROUTE, avant validate(...) : router.post('/', requireAuth, validate(TeamSchema), handler).
// Hier au J0 : le pare-feu de Symfony (security.yaml) faisait ce travail pour vous.
import type { RequestHandler } from 'express';
import { verifyAccessToken } from '../auth/auth.service.js';
import { HttpError } from '../errors.js';

/**
 * TODO 4 (TD JWT, étape 3) :
 *   1. lire req.headers.authorization ; attendu : « Bearer <jeton> » (sinon → HttpError(401, 'Unauthorized'))
 *   2. verifyAccessToken(jeton) (qui lève lui-même 401 'Token expired' ou 'Invalid token')
 *   3. ranger le résultat dans res.locals.user (le handler le lira), puis next()
 * Les 401 portent toujours l'en-tête WWW-Authenticate: Bearer : errorHandler s'en charge.
 */
export const requireAuth: RequestHandler = (req, res, next) => {
  // « Bearer eyJhbGciOi… » : le schéma, un espace, le jeton. Tout autre forme (absent, Basic, vide) → 401.
  const match = /^Bearer (\S+)$/.exec(req.headers.authorization ?? '');
  if (!match) throw new HttpError(401, 'Unauthorized');
  res.locals.user = verifyAccessToken(match[1]!); // lève 401 'Token expired' ou 'Invalid token'
  next();
};
