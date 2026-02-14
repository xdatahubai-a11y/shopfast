#!/usr/bin/env bash
#############################################################################
# Simulate realistic traffic to ShopFast
# Usage: ./traffic.sh <base-url> [--rate 2] [--duration 300]
#############################################################################

URL="${1:-http://localhost:3000}"
RATE=2       # requests per second
DURATION=300 # seconds

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rate) RATE="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

DELAY=$(echo "scale=3; 1/$RATE" | bc)
END=$((SECONDS + DURATION))

echo "🔄 Traffic generator: $URL ($RATE req/s for ${DURATION}s)"

ENDPOINTS=(
  "GET /api/health"
  "GET /api/products"
  "GET /api/products/1"
  "GET /api/products/2"
  "GET /api/orders"
  "GET /api/orders/1"
  "GET /api/orders/2"
  "GET /api/stats"
  "GET /"
)

OK=0 FAIL=0

while [ $SECONDS -lt $END ]; do
  # Pick random endpoint
  ENTRY="${ENDPOINTS[$((RANDOM % ${#ENDPOINTS[@]}))]}"
  METHOD=$(echo "$ENTRY" | cut -d' ' -f1)
  PATH=$(echo "$ENTRY" | cut -d' ' -f2)
  
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X "$METHOD" "${URL}${PATH}" 2>/dev/null || echo "000")
  
  if [ "$CODE" = "200" ]; then
    ((OK++))
  else
    ((FAIL++))
    echo "  ❌ $METHOD $PATH → HTTP $CODE"
  fi
  
  sleep "$DELAY"
done

TOTAL=$((OK + FAIL))
echo ""
echo "📊 Traffic summary: $TOTAL requests, $OK ok, $FAIL failed ($(( FAIL * 100 / (TOTAL+1) ))% error rate)"
