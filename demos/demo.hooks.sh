#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-18
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155 # evaluate E_BASH from project structure if it's not set
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# shellcheck disable=SC1090 source=../.scripts/_hooks.sh
source "$E_BASH/_hooks.sh"

# shellcheck disable=SC1090 source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

echo "${cl_lblue}${st_b}=== e-bash Hooks System Demo ===${st_no_b}${cl_reset}"
echo ""

# ============================================================================
# Example 1: Basic Hook Definition and Execution
# ============================================================================
echo "${cl_cyan}${st_b}Example 1: Basic Hook Definition${st_no_b}${cl_reset}"
echo "----------------------------------------"

# Define available hooks
hooks:define begin end

echo "✓ Defined hooks: begin, end"
echo ""

# Implement hooks as functions
hook:begin() {
  echo "  ${cl_green}→ Begin hook executed${cl_reset}"
}

hook:end() {
  echo "  ${cl_green}→ End hook executed${cl_reset}"
}

# Execute hooks
echo "Calling hooks:"
on:hook begin
echo "  ${cl_grey}[Main script logic here]${cl_reset}"
on:hook end

echo ""

# ============================================================================
# Example 2: Hooks with Parameters
# ============================================================================
echo "${cl_cyan}${st_b}Example 2: Hooks with Parameters${st_no_b}${cl_reset}"
echo "----------------------------------------"

hooks:define greet

hook:greet() {
  local name="$1"
  local title="${2:-User}"
  echo "  ${cl_green}→ Hello, $title $name!${cl_reset}"
}

echo "Calling hook with parameters:"
on:hook greet "Alice" "Dr."
on:hook greet "Bob"

echo ""

# ============================================================================
# Example 3: Decision Hooks
# ============================================================================
echo "${cl_cyan}${st_b}Example 3: Decision Hooks${st_no_b}${cl_reset}"
echo "----------------------------------------"

hooks:define decide

hook:decide() {
  local question="$1"
  echo "  ${cl_yellow}? $question${cl_reset}" >&2
  echo "yes"  # Simulate user saying yes
}

echo "Using decision hook:"
if [[ "$(on:hook decide "Should we continue?")" == "yes" ]]; then
  echo "  ${cl_green}✓ Decision was YES - proceeding${cl_reset}"
else
  echo "  ${cl_red}✗ Decision was NO - stopping${cl_reset}"
fi

echo ""

# ============================================================================
# Example 4: Error Handling Hooks
# ============================================================================
echo "${cl_cyan}${st_b}Example 4: Error Handling${st_no_b}${cl_reset}"
echo "----------------------------------------"

hooks:define error rollback

hook:error() {
  local message="$1"
  local code="${2:-1}"
  echo "  ${cl_red}✗ ERROR: $message (code: $code)${cl_reset}"
}

hook:rollback() {
  echo "  ${cl_yellow}↺ Rolling back changes...${cl_reset}"
  echo "  ${cl_green}✓ Rollback complete${cl_reset}"
}

echo "Simulating error scenario:"
on:hook error "Database connection failed" 42
on:hook rollback

echo ""

# ============================================================================
# Example 5: Hook Introspection
# ============================================================================
echo "${cl_cyan}${st_b}Example 5: Hook Introspection${st_no_b}${cl_reset}"
echo "----------------------------------------"

# Define some hooks without implementations
hooks:define implemented not_implemented custom_hook

hook:implemented() {
  echo "This hook has an implementation"
}

echo "Listing all defined hooks:"
hooks:list

echo ""

echo "Checking specific hooks:"
if hooks:is_defined implemented; then
  echo "  ${cl_green}✓ 'implemented' hook is defined${cl_reset}"
fi

if hooks:has_implementation implemented; then
  echo "  ${cl_green}✓ 'implemented' hook has an implementation${cl_reset}"
fi

if ! hooks:has_implementation not_implemented; then
  echo "  ${cl_yellow}! 'not_implemented' hook has NO implementation${cl_reset}"
fi

echo ""

# ============================================================================
# Example 6: Silent Skipping of Undefined Hooks
# ============================================================================
echo "${cl_cyan}${st_b}Example 6: Silent Skipping${st_no_b}${cl_reset}"
echo "----------------------------------------"

echo "Calling undefined hook (silently skipped):"
on:hook undefined_hook "param1" "param2"
echo "  ${cl_green}✓ Script continued without error${cl_reset}"

echo ""

echo "Calling defined but not implemented hook:"
on:hook not_implemented
echo "  ${cl_green}✓ Script continued without error${cl_reset}"

echo ""

# ============================================================================
# Example 7: Lifecycle Hooks Pattern
# ============================================================================
echo "${cl_cyan}${st_b}Example 7: Lifecycle Pattern${st_no_b}${cl_reset}"
echo "----------------------------------------"

hooks:define pre_validate validate post_validate pre_process process post_process

hook:pre_validate() {
  echo "  ${cl_grey}→ Pre-validation setup${cl_reset}"
}

hook:validate() {
  echo "  ${cl_yellow}→ Validating input...${cl_reset}"
  return 0  # Success
}

hook:post_validate() {
  echo "  ${cl_green}→ Post-validation cleanup${cl_reset}"
}

hook:pre_process() {
  echo "  ${cl_grey}→ Pre-processing setup${cl_reset}"
}

hook:process() {
  echo "  ${cl_yellow}→ Processing data...${cl_reset}"
  return 0  # Success
}

hook:post_process() {
  echo "  ${cl_green}→ Post-processing cleanup${cl_reset}"
}

echo "Executing lifecycle hooks:"
on:hook pre_validate
on:hook validate && echo "  ${cl_green}✓ Validation passed${cl_reset}"
on:hook post_validate

on:hook pre_process
on:hook process && echo "  ${cl_green}✓ Processing complete${cl_reset}"
on:hook post_process

echo ""

# ============================================================================
# Example 8: Return Values and Exit Codes
# ============================================================================
echo "${cl_cyan}${st_b}Example 8: Return Values and Exit Codes${st_no_b}${cl_reset}"
echo "----------------------------------------"

hooks:define success_hook failure_hook

hook:success_hook() {
  echo "  ${cl_green}→ Success hook returning 0${cl_reset}"
  return 0
}

hook:failure_hook() {
  echo "  ${cl_red}→ Failure hook returning 13${cl_reset}"
  return 13
}

echo "Testing exit codes:"
on:hook success_hook
success_code=$?
echo "  Exit code: $success_code ${cl_green}(success)${cl_reset}"

on:hook failure_hook
failure_code=$?
echo "  Exit code: $failure_code ${cl_red}(failure)${cl_reset}"

echo ""

# ============================================================================
# Example 9: Configuration Options
# ============================================================================
echo "${cl_cyan}${st_b}Example 9: Configuration Options${st_no_b}${cl_reset}"
echo "----------------------------------------"

echo "Hook system configuration:"
echo "  HOOKS_DIR=${cl_yellow}${HOOKS_DIR}${cl_reset} (default: .hooks)"
echo "  HOOKS_PREFIX=${cl_yellow}${HOOKS_PREFIX}${cl_reset} (default: hook:)"
echo ""
echo "These can be customized before sourcing the module:"
echo "  ${cl_grey}export HOOKS_DIR=\"my-hooks\"${cl_reset}"
echo "  ${cl_grey}export HOOKS_PREFIX=\"my_prefix:\"${cl_reset}"
echo "  ${cl_grey}source \"\$E_BASH/_hooks.sh\"${cl_reset}"

echo ""

# ============================================================================
# Summary and Usage Instructions
# ============================================================================
echo "${cl_lblue}${st_b}=== Summary ===${st_no_b}${cl_reset}"
echo ""
echo "The hooks system provides:"
echo "  • ${cl_green}Declarative hook definition${cl_reset} via hooks:define"
echo "  • ${cl_green}Flexible implementation${cl_reset} via functions or scripts"
echo "  • ${cl_green}Silent skipping${cl_reset} of undefined/unimplemented hooks"
echo "  • ${cl_green}Parameter passing${cl_reset} to hook implementations"
echo "  • ${cl_green}Return value capture${cl_reset} for decision-making"
echo "  • ${cl_green}Introspection capabilities${cl_reset} for dynamic behavior"
echo ""
echo "Usage patterns:"
echo "  1. ${cl_cyan}hooks:define${cl_reset} hook1 hook2 ...    # Declare hooks"
echo "  2. ${cl_cyan}on:hook${cl_reset} hook_name [params]     # Execute hook"
echo "  3. ${cl_cyan}hooks:list${cl_reset}                     # List all hooks"
echo "  4. ${cl_cyan}hooks:is_defined${cl_reset} hook_name    # Check if defined"
echo "  5. ${cl_cyan}hooks:has_implementation${cl_reset} name # Check if implemented"
echo ""
echo "For more information, see: ${cl_yellow}docs/public/hooks.md${cl_reset}"
echo ""
