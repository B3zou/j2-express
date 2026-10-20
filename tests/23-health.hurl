# ─────────────────────────────────────────────────────────────────────────────
# J2 · TD Redis étape 4 — GET /api/health dit si Redis répond
# Attendu : { status: "ok", database: "ok", redis: "ok" } quand tout tourne
#           (et redis: "down" si Redis est arrêté — l'API répond quand même : essayez-le à la main)
# ─────────────────────────────────────────────────────────────────────────────

GET {{host}}/api/health
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
jsonpath "$.database" == "ok"
jsonpath "$.redis" == "ok"
