#!/bin/bash
# Pre-commit hook: blocks commits that add new source files without tests.
# Install: cp scripts/pre-commit-test-gate.sh .git/hooks/pre-commit
# Or: install.sh does it automatically for toolkit repo.
#
# Logic:
#   - For each NEW file (not modified, NEW) in staging:
#     - Skip if it's a test, type, config, barrel, or structural file
#     - Check if corresponding .test.* exists (staged or on disk)
#     - If not → BLOCK with clear error
#
# Override: git commit --no-verify (use only when you know what you're doing)

set -e

# --- Configuration ---
# File extensions that need tests
SOURCE_EXTS='\.tsx?$|\.py$|\.php$'

# Patterns to SKIP (never require tests for these)
SKIP_PATTERNS=(
  '\.test\.'           # test files themselves
  '\.spec\.'           # spec files
  '__tests__/'         # test directories
  '\.d\.ts$'           # type declaration files
  '\.types\.ts'        # type-only files
  'index\.ts$'         # barrel exports
  'index\.tsx$'        # barrel exports
  '\.config\.'         # config files (vite.config, next.config, etc.)
  'setup\.'            # test setup files
  'fixtures\.'         # test fixtures
  'layout\.tsx$'       # Next.js structural
  'loading\.tsx$'      # Next.js structural
  'error\.tsx$'        # Next.js structural
  'not-found\.tsx$'    # Next.js structural
  'global-error\.tsx$' # Next.js structural
  'template\.tsx$'     # Next.js structural
  'middleware\.ts$'    # Next.js middleware
  'conftest\.py$'      # pytest config
  '\.stories\.'        # Storybook
  '/migrations/'       # DB migrations
  '/scripts/'          # build/deploy scripts
  'tailwind\.'         # Tailwind config
  'postcss\.'          # PostCSS config
  'eslint'             # ESLint config
  'prettier'           # Prettier config
  'tsconfig'           # TypeScript config
  'package\.json$'     # package manifest
  'package-lock'       # lockfile
  '\.env'              # environment files
  '\.md$'              # documentation
  '\.json$'            # JSON data files
  '\.yaml$'            # YAML config
  '\.yml$'             # YAML config
  '\.css$'             # stylesheets
  '\.scss$'            # stylesheets
  '\.svg$'             # assets
)

# --- Detect new source files ---
new_files=$(git diff --cached --name-only --diff-filter=A 2>/dev/null || true)

if [ -z "$new_files" ]; then
  exit 0
fi

missing_tests=()

while IFS= read -r file; do
  # Must be a source file
  if ! echo "$file" | grep -qE "$SOURCE_EXTS"; then
    continue
  fi

  # Check skip patterns
  skip=false
  for pattern in "${SKIP_PATTERNS[@]}"; do
    if echo "$file" | grep -qE "$pattern"; then
      skip=true
      break
    fi
  done
  [ "$skip" = true ] && continue

  # Find expected test file locations
  dir=$(dirname "$file")
  base=$(basename "$file")
  name="${base%.*}"        # foo.tsx → foo
  name="${name%.}"         # handle double extensions
  ext="${base##*.}"        # tsx, ts, py, php

  # Possible test file patterns
  found_test=false

  # Pattern 1: co-located (foo.test.tsx, foo.test.ts)
  for test_ext in "test.$ext" "test.ts" "test.tsx" "spec.$ext" "spec.ts" "spec.tsx"; do
    candidate="$dir/$name.$test_ext"
    # Check staged files
    if echo "$new_files" | grep -qF "$candidate"; then
      found_test=true
      break
    fi
    # Check disk
    if [ -f "$candidate" ]; then
      found_test=true
      break
    fi
  done

  # Pattern 2: __tests__ directory
  if [ "$found_test" = false ]; then
    for test_ext in "test.$ext" "test.ts" "test.tsx" "spec.$ext"; do
      candidate="$dir/__tests__/$name.$test_ext"
      if echo "$new_files" | grep -qF "$candidate"; then
        found_test=true
        break
      fi
      if [ -f "$candidate" ]; then
        found_test=true
        break
      fi
    done
  fi

  # Pattern 3: Python — test_foo.py
  if [ "$found_test" = false ] && [ "$ext" = "py" ]; then
    candidate="$dir/test_$base"
    if echo "$new_files" | grep -qF "$candidate" || [ -f "$candidate" ]; then
      found_test=true
    fi
  fi

  if [ "$found_test" = false ]; then
    missing_tests+=("$file")
  fi
done <<< "$new_files"

# --- Report ---
if [ ${#missing_tests[@]} -gt 0 ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  TEST GATE: New source files without tests detected     ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  for f in "${missing_tests[@]}"; do
    echo "  ✗ $f"
    # Suggest test file name
    dir=$(dirname "$f")
    base=$(basename "$f")
    name="${base%.*}"
    ext="${base##*.}"
    echo "    → Expected: $dir/$name.test.$ext"
  done
  echo ""
  echo "Every new source file needs a corresponding test file."
  echo "See: ~/.claude/rules/testing.md (Iron Rule)"
  echo ""
  echo "Override: git commit --no-verify (not recommended)"
  echo ""
  exit 1
fi
