// Aucun routeur n'a répondu : 404 en JSON. Monté après tous les routeurs, avant errorHandler.
import type { Request, Response } from 'express';

export function notFound(_req: Request, res: Response) {
  res.status(404).json({ title: 'Not Found', status: 404 });
}
