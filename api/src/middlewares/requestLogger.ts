// TD étape 1 : journaliser chaque requête (méthode, URL, statut, durée).
// La réponse n'est pas encore envoyée quand ce middleware s'exécute : on écoute l'événement 'finish'
// de res, émis quand la réponse est partie, pour connaître le statut et la durée.
import type { Request, Response, NextFunction } from 'express';

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = performance.now();
  res.on('finish', () => {
    const ms = (performance.now() - start).toFixed(1);
    console.log(`${req.method} ${req.originalUrl} → ${res.statusCode} (${ms} ms)`);
  });
  next(); // on ne répond pas : on passe la main
}
