// Les routes de l'authentification : s'inscrire, se connecter, savoir qui je suis.
import { Router } from 'express';
import { HttpError } from '../errors.js';
import { requireAuth } from '../middlewares/requireAuth.js';
import { validate } from '../middlewares/validate.js';
import { hashPassword } from './auth.service.js';
import { users } from './user.repository.js';
import { LoginSchema, RegisterSchema, toPublic, type Credentials } from './user.schema.js';

export const authRouter = Router();

// POST /api/auth/register { email, password } → 201 l'utilisateur créé (sans son mot de passe)
authRouter.post('/register', validate(RegisterSchema), async (req, res) => {
  const { email, password } = req.body as Credentials;
  const user = await users.insert({ email, password: await hashPassword(password) });
  res.status(201).json(toPublic(user));
});

// POST /api/auth/login { email, password } → 200 { accessToken, tokenType: 'Bearer', expiresIn }
// TODO 3 (TD JWT, étape 2) : retrouver l'utilisateur par son email, vérifier le mot de passe,
// signer un jeton. Email inconnu ou mot de passe faux → le MÊME 401 'Invalid credentials' (on ne dit pas lequel).
authRouter.post('/login', validate(LoginSchema), async (_req, _res) => {
  throw new HttpError(501, 'Not Implemented');
});

// GET /api/auth/me (protégée) → 200 { id, email } : l'utilisateur du jeton
// TODO 5 (TD JWT, étape 3) : renvoyer res.locals.user, déposé par requireAuth.
authRouter.get('/me', requireAuth, async (_req, _res) => {
  throw new HttpError(501, 'Not Implemented');
});
