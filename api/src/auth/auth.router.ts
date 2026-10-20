// Les routes de l'authentification : s'inscrire, se connecter, savoir qui je suis.
import { Router } from 'express';
import { HttpError } from '../errors.js';
import { requireAuth } from '../middlewares/requireAuth.js';
import { validate } from '../middlewares/validate.js';
import { hashPassword, signAccessToken, verifyPassword, type AuthUser } from './auth.service.js';
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
// Email inconnu ou mot de passe faux → le MÊME 401 'Invalid credentials' (on ne dit pas lequel).
authRouter.post('/login', validate(LoginSchema), async (req, res) => {
  const { email, password } = req.body as Credentials;
  const user = await users.findByEmail(email);
  if (!user || !(await verifyPassword(password, user.password))) throw new HttpError(401, 'Invalid credentials');
  res.json({ ...signAccessToken({ id: user.id, email: user.email }), tokenType: 'Bearer' });
});

// GET /api/auth/me (protégée) → 200 { id, email } : l'utilisateur du jeton
authRouter.get('/me', requireAuth, async (_req, res) => {
  res.json(res.locals.user as AuthUser);
});
