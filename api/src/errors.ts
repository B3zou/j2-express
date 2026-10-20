// Une erreur qui porte son statut HTTP : le middleware errorHandler la transforme en réponse JSON.
// Équivalent des NotFoundHttpException, ConflictHttpException… du J0.

export interface FieldError {
  path: string; // le champ concerné ("teamSize", "team.id"…)
  message: string;
}

export class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
    public errors?: FieldError[],
  ) {
    super(message);
  }
}
