// Refuse en 415 une écriture (POST, PUT, PATCH) qui envoie un corps qui n'est pas du JSON.
// Équivalent du 415 de #[MapRequestPayload] au J0.
import type { Request, Response, NextFunction } from 'express';

export function requireJson(req: Request, res: Response, next: NextFunction) {
  const writes = ['POST', 'PUT', 'PATCH'];
  // Un POST « action » (POST /api/matches/3/play) n'a pas de corps : rien à vérifier.
  // Attention : Swagger UI et les navigateurs envoient alors Content-Length: 0, que req.is() compte
  // comme un corps → on regarde la taille annoncée nous-mêmes.
  const hasBody = req.headers['transfer-encoding'] !== undefined || Number(req.headers['content-length'] ?? 0) > 0;
  if (writes.includes(req.method) && hasBody && !req.is('application/json')) {
    res.status(415).json({ title: 'Unsupported Media Type', status: 415 });
    return; // on répond : on n'appelle pas next()
  }
  next(); // sinon : on passe la main
}
