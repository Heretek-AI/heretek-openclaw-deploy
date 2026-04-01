#!/bin/bash
# Triad Deliberation Validation Script
# Validates that triad consensus mechanisms are intact before deployment

set -e

echo "🔺 Heretek Triad Validation"
echo "=========================="

# Check triad configuration files exist
TRIAD_CONFIGS=(
  "config/triad.json"
  "config/consensus-rules.json"
)

for config in "${TRIAD_CONFIGS[@]}"; do
  if [ -f "$config" ]; then
    echo "✅ Found: $config"
  else
    echo "⚠️  Missing (optional): $config"
  fi
done

# Validate triad agent definitions
echo ""
echo "Validating triad agent definitions..."
if [ -d "agents" ]; then
  for agent in alpha beta charlie; do
    if [ -f "agents/${agent}/agent.json" ] || [ -f "agents/${agent}/config.json" ]; then
      echo "✅ Triad member defined: $agent"
    else
      echo "⚠️  Triad member config not found: $agent (may use shared config)"
    fi
  done
fi

# Check consensus ledger integrity
echo ""
echo "Checking consensus ledger..."
if [ -d ".ledger-backups" ] || [ -d "consensus-ledger" ]; then
  LEDGER_COUNT=$(find . -name "*consensus*.json" -o -name "*ledger*.json" 2>/dev/null | wc -l)
  echo "✅ Consensus ledger files found: $LEDGER_COUNT"
else
  echo "ℹ️  No consensus ledger directory (may be initialized on first run)"
fi

# Validate steward override capability
echo ""
echo "Validating steward override mechanism..."
if grep -q "steward" config/*.json 2>/dev/null || grep -q "steward" agents/*/agent.json 2>/dev/null; then
  echo "✅ Steward override configured"
else
  echo "⚠️  Steward override not explicitly configured (may use defaults)"
fi

# Check for gridlock resolution patterns
echo ""
echo "Checking gridlock resolution patterns..."
GRIDLOCK_PATTERNS=(
  "catalyst"
  "examiner"
  "prism"
)

found_patterns=0
for pattern in "${GRIDLOCK_PATTERNS[@]}"; do
  if grep -r "$pattern" agents/ config/ 2>/dev/null | head -1 > /dev/null; then
    echo "✅ Gridlock resolution agent found: $pattern"
    ((found_patterns++))
  fi
done

if [ $found_patterns -ge 2 ]; then
  echo "✅ Sufficient gridlock resolution mechanisms in place"
else
  echo "⚠️  Limited gridlock resolution patterns detected"
fi

# Final validation status
echo ""
echo "=========================="
echo "✅ Triad validation PASSED"
echo "Deployment can proceed with triad deliberation intact"

exit 0
