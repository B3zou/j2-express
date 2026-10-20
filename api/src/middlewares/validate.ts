// Deux fabriques de middlewares de validation (zod) :
//   validate(schema)      → vérifie req.body, répond 422, remplace req.body par les données nettoyées
//   validateQuery(schema) → vérifie req.query (?page=2…), répond 400, dépose le résultat dans res.locals.query
// Équivalent de #[MapRequestPayload] (corps) et #[MapQueryParameter] (requête) au J0.
import type { RequestHandler } from 'express';
import type { z } from 'zod';
import type { FieldError } from '../errors.js';

function issuesOf(error: z.ZodError): FieldError[] {
  return error.issues.map((issue) => ({ path: issue.path.join('.'), message: issue.message }));
}

export function validate(schema: z.ZodType): RequestHandler {
  return (req, res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      res.status(422).json({ title: 'Validation Failed', status: 422, errors: issuesOf(result.error) });
      return;
    }
    req.body = result.data; // des données propres (clés inconnues retirées) pour le handler
    next();
  };
}

export function validateQuery(schema: z.ZodType): RequestHandler {
  return (req, res, next) => {
    const result = schema.safeParse(req.query);
    if (!result.success) {
      res.status(400).json({ title: 'Bad Request', status: 400, errors: issuesOf(result.error) });
      return;
    }
    res.locals.query = result.data; // req.query est en lecture seule (Express 5) : on range le résultat ici
    next();
  };
}
