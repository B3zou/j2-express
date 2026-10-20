// Le simulateur de match : un service fourni, PUR (pas de base, pas d'Express), identique au J0.
// Un match se joue au meilleur des 5 manches ; chaque manche est tirée au sort selon le niveau
// moyen des deux équipes. Avec une graine (seed), le tirage est reproductible.
// Vous n'avez pas à modifier ce fichier : vous l'appelez depuis un routeur.

export interface TeamSide {
  id: number;
  name: string;
  tag: string;
  rating: number; // niveau moyen de l'équipe (entier)
}

export interface MatchResult {
  teamA: TeamSide;
  teamB: TeamSide;
  score: [number, number];
  winner: string; // le tag de l'équipe gagnante
  rounds: string[]; // le tag du gagnant de chaque manche, dans l'ordre
}

const ROUNDS_TO_WIN = 3;

/** La moyenne entière d'une liste de niveaux. Lève une erreur si la liste est vide. */
export function averageRating(ratings: number[]): number {
  if (ratings.length === 0) throw new RangeError('no players');
  return Math.round(ratings.reduce((sum, r) => sum + r, 0) / ratings.length);
}

/** Un générateur pseudo-aléatoire reproductible (mulberry32) : même graine, même suite. */
function seeded(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function simulate(teamA: TeamSide, teamB: TeamSide, seed?: number): MatchResult {
  const random = seed === undefined ? Math.random : seeded(seed);
  const probabilityA = teamA.rating / (teamA.rating + teamB.rating);
  const score: [number, number] = [0, 0];
  const rounds: string[] = [];

  while (Math.max(...score) < ROUNDS_TO_WIN) {
    const aWins = random() < probabilityA;
    score[aWins ? 0 : 1] += 1;
    rounds.push(aWins ? teamA.tag : teamB.tag);
  }

  return { teamA, teamB, score, winner: score[0] > score[1] ? teamA.tag : teamB.tag, rounds };
}
