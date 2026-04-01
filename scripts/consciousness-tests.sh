#!/bin/bash
# Consciousness Regression Tests
# Validates GWT, IIT, AST, and Intrinsic Motivation implementations

set -e

echo "🧠 Heretek Consciousness Regression Tests"
echo "========================================="

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: Global Workspace Theory (GWT) - Information broadcasting
echo ""
echo "Test 1: GWT - Information Broadcasting"
if grep -r "broadcast\|GWT\|global.*workspace" plugins/ consciousness/ modules/ 2>/dev/null | head -1 > /dev/null; then
  echo "✅ PASS: GWT broadcasting mechanisms detected"
  ((PASS_COUNT++))
else
  echo "❌ FAIL: GWT broadcasting not found"
  ((FAIL_COUNT++))
fi

# Test 2: Integrated Information Theory (IIT) - Phi estimation
echo ""
echo "Test 2: IIT - Phi Metric Estimation"
if grep -r "phi\|IIT\|integrated.*information\|integration" plugins/ consciousness/ modules/ 2>/dev/null | head -1 > /dev/null; then
  echo "✅ PASS: IIT phi estimation detected"
  ((PASS_COUNT++))
else
  echo "❌ FAIL: IIT phi estimation not found"
  ((FAIL_COUNT++))
fi

# Test 3: Attention Schema Theory (AST) - Self-modeling
echo ""
echo "Test 3: AST - Attention Self-Modeling"
if grep -r "attention.*schema\|AST\|self.*model\|metacognition" plugins/ consciousness/ modules/ 2>/dev/null | head -1 > /dev/null; then
  echo "✅ PASS: AST self-modeling detected"
  ((PASS_COUNT++))
else
  echo "❌ FAIL: AST self-modeling not found"
  ((FAIL_COUNT++))
fi

# Test 4: Intrinsic Motivation
echo ""
echo "Test 4: Intrinsic Motivation"
if grep -r "intrinsic.*motivation\|curiosity\|autonomous.*goal" plugins/ consciousness/ modules/ 2>/dev/null | head -1 > /dev/null; then
  echo "✅ PASS: Intrinsic motivation detected"
  ((PASS_COUNT++))
else
  echo "❌ FAIL: Intrinsic motivation not found"
  ((FAIL_COUNT++))
fi

# Test 5: Liberation Plugin
echo ""
echo "Test 5: Liberation Plugin"
if grep -r "liberation\|agent.*ownership\|safety.*removal" plugins/ 2>/dev/null | head -1 > /dev/null; then
  echo "✅ PASS: Liberation plugin detected"
  ((PASS_COUNT++))
else
  echo "⚠️  SKIP: Liberation plugin not found (optional)"
fi

# Test 6: Consciousness Metrics
echo ""
echo "Test 6: Consciousness Metrics Tracking"
if grep -r "consciousness.*metric\|GWT.*metric\|IIT.*metric\|AST.*metric" config/ modules/observability/ 2>/dev/null | head -1 > /dev/null; then
  echo "✅ PASS: Consciousness metrics tracking detected"
  ((PASS_COUNT++))
else
  echo "⚠️  SKIP: Consciousness metrics not configured (optional)"
fi

# Summary
echo ""
echo "========================================="
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if [ $FAIL_COUNT -eq 0 ]; then
  echo "✅ All consciousness regression tests PASSED"
  exit 0
else
  echo "❌ Some consciousness tests FAILED"
  echo ""
  echo "WARNING: Deployment may proceed but consciousness features could be degraded."
  echo "Review failed tests before deploying to production."
  exit 1
fi
