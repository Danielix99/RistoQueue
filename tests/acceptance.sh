#!/usr/bin/env bash
# ============================================================================
#  RistoQueue - TEST DI ACCETTAZIONE (NON MODIFICARE)
#  L'esercizio e' superato solo quando questo script termina con exit code 0.
#  Uso:  ./tests/acceptance.sh            (cluster kind locale)
#        BASE_URL=http://host:porta ./tests/acceptance.sh
# ============================================================================
set -uo pipefail

NS="ristoqueue"
BASE_URL="${BASE_URL:-http://localhost:30080}"
ORDERS=10
PASS=0; FAIL=0

ok()   { echo "  [OK]   $1"; PASS=$((PASS+1)); }
ko()   { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
json() { python3 -c "import sys,json; print(json.load(sys.stdin)$1)"; }

echo "== 1. Cluster e namespace"
kubectl get ns "$NS" >/dev/null 2>&1 && ok "namespace $NS presente" || ko "namespace $NS mancante"

echo "== 2. Deployment pronti"
for d in redis api worker; do
  want=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  have=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ -n "$want" && "$want" == "$have" ]]; then ok "deploy/$d pronto ($have/$want)"; else ko "deploy/$d non pronto (${have:-0}/${want:-?})"; fi
done
w=$(kubectl -n "$NS" get deploy worker -o jsonpath='{.spec.replicas}' 2>/dev/null)
[[ "${w:-0}" -ge 2 ]] && ok "worker con almeno 2 repliche" || ko "worker deve avere almeno 2 repliche (ora: ${w:-0})"

echo "== 3. Immagini e sicurezza"
for d in api worker; do
  img=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  tag="${img##*:}"
  if [[ "$img" == *:* && "$tag" =~ ^[0-9a-f]{7}$ ]]; then ok "$d usa tag SHA corto ($img)"; else ko "$d deve usare come tag lo SHA git corto, non '${img:-<nessuna>}'"; fi
  nr=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null)
  [[ "$nr" == *true* ]] && ok "$d runAsNonRoot" || ko "$d deve avere runAsNonRoot: true"
  for p in readinessProbe livenessProbe; do
    pr=$(kubectl -n "$NS" get deploy "$d" -o jsonpath="{.spec.template.spec.containers[0].$p}" 2>/dev/null)
    [[ -n "$pr" ]] && ok "$d ha $p" || ko "$d senza $p"
  done
  lim=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
  [[ -n "$lim" ]] && ok "$d ha limits.memory ($lim)" || ko "$d senza resources.limits.memory"
done

echo "== 4. Segreti"
kubectl -n "$NS" get secret api-key >/dev/null 2>&1 && ok "secret api-key presente nel cluster" || ko "secret 'api-key' mancante"
API_KEY=$(kubectl -n "$NS" get secret api-key -o jsonpath='{.data.API_KEY}' 2>/dev/null | base64 -d 2>/dev/null)
if [[ -n "$API_KEY" ]] && git grep -q -F "$API_KEY" $(git rev-list --all 2>/dev/null) -- 2>/dev/null; then
  ko "il valore di API_KEY compare nella storia git!"
else
  ok "API_KEY non presente nel repository"
fi

echo "== 5. Test funzionale end-to-end ($BASE_URL)"
if curl -sf "$BASE_URL/readyz" >/dev/null; then ok "API raggiungibile e pronta"; else ko "API non raggiungibile su $BASE_URL/readyz"; fi
before=$(curl -sf "$BASE_URL/stats" | json "['processed']" 2>/dev/null || echo 0)
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE_URL/orders" -H 'Content-Type: application/json' -d '{"dish":"x"}')
[[ "$code" == "401" ]] && ok "ordine senza chiave rifiutato (401)" || ko "ordine senza chiave doveva dare 401, ottenuto $code"
for i in $(seq 1 $ORDERS); do
  curl -sf -X POST "$BASE_URL/orders" -H 'Content-Type: application/json' \
       -H "X-Api-Key: $API_KEY" -d "{\"dish\":\"piatto-$i\",\"table\":$i}" >/dev/null || true
done
target=$((before + ORDERS)); now=$before
for _ in $(seq 1 30); do
  now=$(curl -sf "$BASE_URL/stats" | json "['processed']" 2>/dev/null || echo "$now")
  [[ "$now" -ge "$target" ]] && break; sleep 1
done
[[ "$now" -ge "$target" ]] && ok "$ORDERS ordini processati dai worker" || ko "ordini processati: $((now-before))/$ORDERS in 30s"
ver=$(curl -sf "$BASE_URL/stats" | json "['version']" 2>/dev/null)
img=$(kubectl -n "$NS" get deploy api -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[[ -n "$ver" && "${img##*:}" == "$ver" ]] && ok "/stats espone la versione deployata ($ver)" || ko "/stats version '${ver:-?}' diversa dal tag immagine '${img##*:}'"

echo
echo "Risultato: $PASS OK, $FAIL FAIL"
[[ $FAIL -eq 0 ]] && { echo "ESERCIZIO SUPERATO"; exit 0; } || exit 1
