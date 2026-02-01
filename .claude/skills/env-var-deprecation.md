# Env Var Deprecation Skill

When removing or deprecating environment variables from this project, use this checklist to ensure complete removal from all locations.

## Checklist for Removing an Environment Variable

When an env var (e.g., `SOME_VAR`) is deprecated or removed:

### 1. Configuration Files
- [ ] `config.env.example` - Remove the variable and any comments about it
- [ ] `config.env` (if exists) - User's local config (mention in PR/commit for user awareness)

### 2. Shell Scripts (scripts/*.sh)
- [ ] `scripts/setup.sh` - Remove from setup messages and recommendations
- [ ] `scripts/chat.sh` - Remove usage, defaults, and help text
- [ ] `scripts/query.sh` - Remove usage, defaults, and help text
- [ ] `scripts/serve.sh` - Remove usage, defaults, and help text
- [ ] `scripts/download-model.sh` - Remove if used for download settings

### 3. Build/Make Files
- [ ] `Makefile` - Remove from `info` target and any other references

### 4. Documentation
- [ ] `README.md` - Remove from configuration tables, examples, and quick start
- [ ] `CLAUDE.md` - Remove from configuration tables and guidance
- [ ] `docs/CONCEPTS.md` - Remove from explanations
- [ ] `docs/TROUBLESHOOTING.md` - Remove from troubleshooting guides

### 5. Tests (tests/*.bats)
- [ ] `tests/config.bats` - Remove tests that validate the variable
- [ ] `tests/download.bats` - Remove if tested there
- [ ] `tests/test_helper.bash` - Remove from test config templates

## Verification Command

After removing an env var, run this grep to verify complete removal:

```bash
grep -r "VAR_NAME" --include="*.sh" --include="*.md" --include="*.bats" --include="Makefile" --include="*.env*" .
```

Replace `VAR_NAME` with the actual variable name (e.g., `RAM_LIMIT`).

## Example: Removing RAM_LIMIT

When RAM_LIMIT was deprecated (replaced by KV_CACHE_TYPE_K/V), these locations needed updates:

1. `config.env.example` - Removed RAM_LIMIT, added KV_CACHE_TYPE_K/V
2. `scripts/setup.sh` - Removed RAM_LIMIT recommendation message
3. `scripts/chat.sh` - Removed convert_ram_to_mib(), --cache-ram flag, help text
4. `scripts/query.sh` - Same as chat.sh
5. `scripts/serve.sh` - Same as chat.sh
6. `Makefile` - Removed RAM_LIMIT from info target, replaced with KV_CACHE_TYPE
7. `README.md` - Updated configuration tables and examples
8. `CLAUDE.md` - Updated configuration table
9. `docs/TROUBLESHOOTING.md` - Updated memory troubleshooting guidance
10. `tests/config.bats` - Replaced RAM_LIMIT tests with KV_CACHE_TYPE tests
11. `tests/download.bats` - Updated config validation test
12. `tests/test_helper.bash` - Updated test config template
