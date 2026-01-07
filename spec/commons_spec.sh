#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2288,SC2155,SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

% TEST_DIR: "$SHELLSPEC_TMPBASE/.secrets"

Mock logger
  echo "$@"
End

Mock echo:Common
  echo "$@"
End

Include ".scripts/_commons.sh"

Describe "_commons.sh /"
  # remove colors in output
  BeforeCall "unset cl_red cl_green cl_blue cl_purple cl_yellow cl_reset"
  BeforeCall 'export DEBUG="*"'

  It "args:isHelp returns true when --help flag is provided"
    When call args:isHelp --help

    The status should be success
    The output should eq true
    The error should eq ''
    # Dump
  End

  Describe "env:variable:or:secret:file /"
    It "No variable or secret file provided error"
      When call env:variable:or:secret:file "new_value" \
        "GITLAB_CI_INTEGRATION_TEST" \
        ".secrets/gitlab_ci_integration_test"

      The status should be failure
      The output should include "ERROR: bash env variable '\$GITLAB_CI_INTEGRATION_TEST' or file '.secrets/gitlab_ci_integration_test' should be provided"
      The error should eq ''

      # Dump
    End

    It "Profided environment variable GITLAB_CI_INTEGRATION_TEST"
      preserve() { %preserve new_value:VALUE; }
      AfterCall preserve
      BeforeCall "export GITLAB_CI_INTEGRATION_TEST='<secret>'"
      When call env:variable:or:secret:file "new_value" \
        "GITLAB_CI_INTEGRATION_TEST" \
        ".secrets/gitlab_ci_integration_test"

      The status should be success

      # DISABLED: eval does not publish new_value during test, due to test isolation
      # The variable VALUE should eq '<secret>'

      The output should include "Using var : \$GITLAB_CI_INTEGRATION_TEST ~> new_value"
      The error should eq ''
    End

    Describe "With provided secret file /"
      folder() { mkdir -p "$TEST_DIR"; }
      file() { touch "$TEST_DIR/gitlab_ci_integration_test"; }
      content() { echo "<secret>" >"$TEST_DIR/gitlab_ci_integration_test"; }
      destroy() { rm "$TEST_DIR/gitlab_ci_integration_test"; }

      Before 'folder; file; content'
      After 'destroy'

      It "Extract value from profided secret file gitlab_ci_integration_test"
        preserve() { %preserve new_value:VALUE; }
        AfterCall preserve

        When call env:variable:or:secret:file "new_value" \
          "GITLAB_CI_INTEGRATION_TEST" \
          "$TEST_DIR/gitlab_ci_integration_test"

        The status should be success
        The variable VALUE should eq '<secret>'

        The output should include "Using file: $TEST_DIR/gitlab_ci_integration_test ~> new_value"
        The error should eq ''

        # Dump
      End

      It "If provided environment variable and secret file, value selected from env variable"
        preserve() { %preserve new_value:VALUE; }
        AfterCall preserve
        BeforeCall "export GITLAB_CI_INTEGRATION_TEST='<secret2>'"

        When call env:variable:or:secret:file "new_value" \
          "GITLAB_CI_INTEGRATION_TEST" \
          "$TEST_DIR/gitlab_ci_integration_test"

        The status should be success
        The variable VALUE should eq '<secret2>'

        The output should include "Using var : \$GITLAB_CI_INTEGRATION_TEST ~> new_value"
        The error should eq ''
      End
    End
  End

  Describe "env:variable:or:secret:file:optional /"
    It "No variable or secret file provided error"
      When call env:variable:or:secret:file:optional "new_value" \
        "GITLAB_CI_INTEGRATION_TEST" \
        ".secrets/gitlab_ci_integration_test"

      The status should be success
      The output should include "Note: bash env variable '\$GITLAB_CI_INTEGRATION_TEST' or file '.secrets/gitlab_ci_integration_test' can be provided."
      The error should eq ''

      # Dump
    End

    It "Profided environment variable GITLAB_CI_INTEGRATION_TEST"
      preserve() { %preserve new_value:VALUE; }
      AfterCall preserve
      BeforeCall "export GITLAB_CI_INTEGRATION_TEST='<secret>'"
      When call env:variable:or:secret:file:optional "new_value" \
        "GITLAB_CI_INTEGRATION_TEST" \
        ".secrets/gitlab_ci_integration_test"

      # Dump

      The status should be success # return: 1
      The variable VALUE should eq '<secret>'

      The output should include "Using var : \$GITLAB_CI_INTEGRATION_TEST ~> new_value"
      The error should eq ''
    End

    Describe "With provided secret file /"
      folder() { mkdir -p "$TEST_DIR"; }
      file() { touch "$TEST_DIR/gitlab_ci_integration_test"; }
      content() { echo "<secret>" >"$TEST_DIR/gitlab_ci_integration_test"; }
      destroy() { rm "$TEST_DIR/gitlab_ci_integration_test"; }

      Before 'folder; file; content'
      After 'destroy'

      It "Extract value from profided secret file gitlab_ci_integration_test"
        preserve() { %preserve new_value:VALUE; }
        AfterCall preserve

        When call env:variable:or:secret:file:optional "new_value" \
          "GITLAB_CI_INTEGRATION_TEST" \
          "$TEST_DIR/gitlab_ci_integration_test"

        # Dump

        The status should be success # return: 2
        The variable VALUE should eq '<secret>'

        The output should include "Using file: $TEST_DIR/gitlab_ci_integration_test ~> new_value"
        The error should eq ''
      End
    End
  End

  Describe "var:l0 /"
    It "Returns variable value when variable is set and non-empty"
      BeforeCall "export MY_VAR='hello world'"
      When call var:l0 "MY_VAR" "default_value"

      The status should be success
      The output should eq "hello world"
      The error should eq ''
    End

    It "Returns default when variable is unset"
      BeforeCall "unset UNSET_VAR"
      When call var:l0 "UNSET_VAR" "default_value"

      The status should be success
      The output should eq "default_value"
      The error should eq ''
    End

    It "Returns default when variable is empty"
      BeforeCall "export EMPTY_VAR=''"
      When call var:l0 "EMPTY_VAR" "default_value"

      The status should be success
      The output should eq "default_value"
      The error should eq ''
    End

    It "Handles special characters in variable value"
      BeforeCall "export SPECIAL_VAR='hello@world#123'"
      When call var:l0 "SPECIAL_VAR" "default"

      The status should be success
      The output should eq "hello@world#123"
      The error should eq ''
    End
  End

  Describe "var:l1 /"
    It "Returns first variable value when first variable is set"
      BeforeCall "export VAR1='first'"
      BeforeCall "export VAR2='second'"
      When call var:l1 "VAR1" "VAR2" "default_value"

      The status should be success
      The output should eq "first"
      The error should eq ''
    End

    It "Returns second variable value when first is unset"
      BeforeCall "unset VAR1"
      BeforeCall "export VAR2='second'"
      When call var:l1 "VAR1" "VAR2" "default_value"

      The status should be success
      The output should eq "second"
      The error should eq ''
    End

    It "Returns second variable value when first is empty"
      BeforeCall "export VAR1=''"
      BeforeCall "export VAR2='second'"
      When call var:l1 "VAR1" "VAR2" "default_value"

      The status should be success
      The output should eq "second"
      The error should eq ''
    End

    It "Returns default when both variables are unset"
      BeforeCall "unset VAR1"
      BeforeCall "unset VAR2"
      When call var:l1 "VAR1" "VAR2" "default_value"

      The status should be success
      The output should eq "default_value"
      The error should eq ''
    End

    It "Returns default when both variables are empty"
      BeforeCall "export VAR1=''"
      BeforeCall "export VAR2=''"
      When call var:l1 "VAR1" "VAR2" "default_value"

      The status should be success
      The output should eq "default_value"
      The error should eq ''
    End

    It "Handles complex fallback chain correctly"
      BeforeCall "unset PRIM_VAR"
      BeforeCall "export SEC_VAR='secondary'"
      When call var:l1 "PRIM_VAR" "SEC_VAR" "fallback"

      The status should be success
      The output should eq "secondary"
      The error should eq ''
    End
  End

  Describe "val:l0 /"
    It "Returns value when value is non-empty"
      When call val:l0 "hello world" "default_value"

      The status should be success
      The output should eq "hello world"
      The error should eq ''
    End

    It "Returns default when value is empty"
      When call val:l0 "" "default_value"

      The status should be success
      The output should eq "default_value"
      The error should eq ''
    End

    It "Handles numeric values"
      When call val:l0 "12345" "0"

      The status should be success
      The output should eq "12345"
      The error should eq ''
    End

    It "Handles special characters in value"
      When call val:l0 "test@value#123" "default"

      The status should be success
      The output should eq "test@value#123"
      The error should eq ''
    End

    It "Handles spaces in value"
      When call val:l0 "value with spaces" "default"

      The status should be success
      The output should eq "value with spaces"
      The error should eq ''
    End
  End

  Describe "val:l1 /"
    It "Returns first value when first value is non-empty"
      When call val:l1 "first" "second" "default_value"

      The status should be success
      The output should eq "first"
      The error should eq ''
    End

    It "Returns second value when first is empty"
      When call val:l1 "" "second" "default_value"

      The status should be success
      The output should eq "second"
      The error should eq ''
    End

    It "Returns default when both values are empty"
      When call val:l1 "" "" "default_value"

      The status should be success
      The output should eq "default_value"
      The error should eq ''
    End

    It "Handles numeric values correctly"
      When call val:l1 "0" "1" "2"

      The status should be success
      The output should eq "0"
      The error should eq ''
    End

    It "Handles special characters in values"
      When call val:l1 "value@1#test" "value2" "default"

      The status should be success
      The output should eq "value@1#test"
      The error should eq ''
    End

    It "Handles spaces in values"
      When call val:l1 "first value" "second value" "default value"

      The status should be success
      The output should eq "first value"
      The error should eq ''
    End

    It "Falls through empty first to non-empty second"
      When call val:l1 "" "second value" "default"

      The status should be success
      The output should eq "second value"
      The error should eq ''
    End
  End

  Describe "Composable fallback patterns (4-level nesting) /"
    # These tests demonstrate how var:l1 and val:l1 can be composed
    # to create deeper fallback chains, simulating var:l3, var:l4, etc.

    It "Simulates var:l3 with nested var:l1 calls - first level wins"
      BeforeCall "export VAR1='level1'"
      BeforeCall "export VAR2='level2'"
      BeforeCall "export VAR3='level3'"

      # var:l3 pattern: var:l1 var1 var2 (var:l1 var3 default)
      test_var_l3_first() {
        var:l1 "VAR1" "VAR2" "$(var:l1 'VAR3' 'UNSET' 'default')"
      }
      When call test_var_l3_first

      The status should be success
      The output should eq "level1"
      The error should eq ''
    End

    It "Simulates var:l3 with nested var:l1 calls - second level wins"
      BeforeCall "unset VAR1"
      BeforeCall "export VAR2='level2'"
      BeforeCall "export VAR3='level3'"

      test_var_l3_second() {
        var:l1 "VAR1" "VAR2" "$(var:l1 'VAR3' 'UNSET' 'default')"
      }
      When call test_var_l3_second

      The status should be success
      The output should eq "level2"
      The error should eq ''
    End

    It "Simulates var:l3 with nested var:l1 calls - third level wins"
      BeforeCall "unset VAR1"
      BeforeCall "unset VAR2"
      BeforeCall "export VAR3='level3'"

      test_var_l3_third() {
        var:l1 "VAR1" "VAR2" "$(var:l1 'VAR3' 'UNSET' 'default')"
      }
      When call test_var_l3_third

      The status should be success
      The output should eq "level3"
      The error should eq ''
    End

    It "Simulates var:l3 with nested var:l1 calls - default wins"
      BeforeCall "unset VAR1"
      BeforeCall "unset VAR2"
      BeforeCall "unset VAR3"

      test_var_l3_default() {
        var:l1 "VAR1" "VAR2" "$(var:l1 'VAR3' 'UNSET' 'default')"
      }
      When call test_var_l3_default

      The status should be success
      The output should eq "default"
      The error should eq ''
    End

    It "Simulates var:l4 with composable variable name - var4 pattern"
      # Simulate a script-specific configuration pattern:
      # Try VAR1 -> VAR2 -> VAR3 -> VAR3_COMMONS_SPEC -> default
      BeforeCall "unset VAR1"
      BeforeCall "unset VAR2"
      BeforeCall "unset VAR3"
      BeforeCall "export VAR3_COMMONS_SPEC='script_specific_value'"

      # Construct var4 name from var3 base + script name
      test_var_l4_script_specific() {
        local var3_base="VAR3"
        local script_name="commons_spec"
        local script_name_upper=$(echo "$script_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        local var4="${var3_base}_${script_name_upper}"

        # var:l4 pattern: var:l1 var1 var2 (var:l1 var3 var4 default)
        var:l1 "VAR1" "VAR2" "$(var:l1 "$var3_base" "$var4" 'default')"
      }
      When call test_var_l4_script_specific

      The status should be success
      The output should eq "script_specific_value"
      The error should eq ''
    End

    It "Simulates var:l4 with composable variable name - fallback to default"
      BeforeCall "unset VAR1"
      BeforeCall "unset VAR2"
      BeforeCall "unset VAR3"
      BeforeCall "unset VAR3_COMMONS_SPEC"

      test_var_l4_fallback() {
        local var3_base="VAR3"
        local script_name="commons_spec"
        local script_name_upper=$(echo "$script_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        local var4="${var3_base}_${script_name_upper}"

        var:l1 "VAR1" "VAR2" "$(var:l1 "$var3_base" "$var4" 'fallback_value')"
      }
      When call test_var_l4_fallback

      The status should be success
      The output should eq "fallback_value"
      The error should eq ''
    End

    It "Simulates var:l4 with composable variable name - multiple scripts pattern"
      # Demonstrates a real-world pattern for script-specific overrides:
      # Global -> User -> Project -> Script-specific -> Default
      BeforeCall "unset GLOBAL_CONFIG"
      BeforeCall "unset USER_CONFIG"
      BeforeCall "unset PROJECT_CONFIG"
      BeforeCall "export PROJECT_CONFIG_TEST_RUNNER='test_runner_override'"

      test_var_l4_multi_script() {
        local base_var="PROJECT_CONFIG"
        local script_context="test_runner"
        local script_context_upper=$(echo "$script_context" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        local script_specific_var="${base_var}_${script_context_upper}"

        # 4-level nested pattern
        var:l1 "GLOBAL_CONFIG" "USER_CONFIG" \
          "$(var:l1 "$base_var" "$script_specific_var" 'default_config')"
      }
      When call test_var_l4_multi_script

      The status should be success
      The output should eq "test_runner_override"
      The error should eq ''
    End

    It "Combines val:l1 and var:l1 for mixed value/variable fallbacks"
      BeforeCall "unset ENV_VAR1"
      BeforeCall "export ENV_VAR2='env_value'"

      # Pattern: try hardcoded value, then env var1, then env var2, then default
      # val:l1 "hardcoded" (var:l1 ENV_VAR1 ENV_VAR2 "default")
      test_mixed_val_var() {
        val:l1 "" "$(var:l1 'ENV_VAR1' 'ENV_VAR2' 'final_default')" "should_not_reach"
      }
      When call test_mixed_val_var

      The status should be success
      The output should eq "env_value"
      The error should eq ''
    End

    It "Complex real-world pattern: CLI arg -> ENV var -> Config file -> Script-specific -> Default"
      # Simulates: CLI_ARG -> ENV_VAR -> CONFIG_PATH -> CONFIG_PATH_SCRIPTNAME -> hardcoded default
      BeforeCall "unset ENV_VAR"
      BeforeCall "unset CONFIG_PATH"
      BeforeCall "export CONFIG_PATH_INSTALLER='/opt/custom/path'"

      # Multi-level composition:
      # val:l1 CLI_ARG (var:l1 ENV_VAR (var:l1 CONFIG_PATH CONFIG_PATH_INSTALLER default))
      test_complex_real_world() {
        local cli_arg=""  # No CLI argument provided
        local config_base="CONFIG_PATH"
        local script_name="installer"
        local script_name_upper=$(echo "$script_name" | tr '[:lower:]' '[:upper:]')
        local config_script_specific="${config_base}_${script_name_upper}"

        val:l1 "$cli_arg" \
          "$(var:l1 'ENV_VAR' "$config_base" \
            "$(var:l1 "$config_base" "$config_script_specific" '/usr/local/default')")" \
          "unreachable"
      }
      When call test_complex_real_world

      The status should be success
      The output should eq "/opt/custom/path"
      The error should eq ''
    End

    It "Deep nesting with all levels empty except final default"
      BeforeCall "unset L1"
      BeforeCall "unset L2"
      BeforeCall "unset L3"
      BeforeCall "unset L4"

      # 4-level deep nesting, all empty
      When call var:l1 "L1" "L2" \
        "$(var:l1 'L3' 'L4' 'ultimate_fallback')"

      The status should be success
      The output should eq "ultimate_fallback"
      The error should eq ''
    End

    It "Demonstrates variable name composition with multiple separators"
      # Pattern: APP_ENV_MODULE_FEATURE
      BeforeCall "unset APP_CONFIG"
      BeforeCall "unset APP_CONFIG_DEV"
      BeforeCall "unset APP_CONFIG_DEV_AUTH"
      BeforeCall "export APP_CONFIG_DEV_AUTH_OAUTH='oauth2_enabled'"

      test_progressive_specificity() {
        local app="APP_CONFIG"
        local env="DEV"
        local module="AUTH"
        local feature="OAUTH"
        local composed_var="${app}_${env}_${module}_${feature}"

        # Try base configs with progressive specificity
        var:l1 "$app" "${app}_${env}" \
          "$(var:l1 "${app}_${env}_${module}" "$composed_var" 'disabled')"
      }
      When call test_progressive_specificity

      The status should be success
      The output should eq "oauth2_enabled"
      The error should eq ''
    End
  End

  Describe "CI Configuration Hierarchy (4-level: Global->Pipeline->Step->Script) /"
    # Real-world CI/CD configuration hierarchy demonstrating the requirement:
    # Level 0 (Global): CI_GLOBAL_* - Affects all pipelines
    # Level 1 (Pipeline): CI_PIPELINE_* - Context for entire flow (e.g., release, testing)
    # Level 2 (Step): CI_STEP_* - Specific stage overrides (e.g., build, lint)
    # Level 3 (Script): CI_SCRIPT_* - Individual script context (granular control)
    # Level 3 > Level 2 > Level 1 > Level 0 > default

    It "Level 0 (Global) - fallback to global when no other levels set"
      BeforeCall "export CI_GLOBAL_DRY_RUN='true'"
      BeforeCall "unset CI_PIPELINE_RELEASE_DRY_RUN"
      BeforeCall "unset CI_STEP_BUILD_DRY_RUN"
      BeforeCall "unset CI_SCRIPT_DEPLOY_DRY_RUN"

      # Hierarchy: Script -> Step -> Pipeline -> Global -> default
      test_ci_level0() {
        var:l1 "CI_SCRIPT_DEPLOY_DRY_RUN" "CI_STEP_BUILD_DRY_RUN" \
          "$(var:l1 'CI_PIPELINE_RELEASE_DRY_RUN' 'CI_GLOBAL_DRY_RUN' 'false')"
      }
      When call test_ci_level0

      The status should be success
      The output should eq "true"
      The error should eq ''
    End

    It "Level 1 (Pipeline) - pipeline overrides global"
      BeforeCall "export CI_GLOBAL_DRY_RUN='true'"
      BeforeCall "export CI_PIPELINE_RELEASE_DRY_RUN='false'"
      BeforeCall "unset CI_STEP_BUILD_DRY_RUN"
      BeforeCall "unset CI_SCRIPT_DEPLOY_DRY_RUN"

      When call var:l1 "CI_SCRIPT_DEPLOY_DRY_RUN" "CI_STEP_BUILD_DRY_RUN" \
        "$(var:l1 'CI_PIPELINE_RELEASE_DRY_RUN' 'CI_GLOBAL_DRY_RUN' 'false')"

      The status should be success
      The output should eq "false"
      The error should eq ''
    End

    It "Level 2 (Step) - step overrides pipeline and global"
      BeforeCall "export CI_GLOBAL_DRY_RUN='true'"
      BeforeCall "export CI_PIPELINE_RELEASE_DRY_RUN='true'"
      BeforeCall "export CI_STEP_BUILD_DRY_RUN='false'"
      BeforeCall "unset CI_SCRIPT_DEPLOY_DRY_RUN"

      When call var:l1 "CI_SCRIPT_DEPLOY_DRY_RUN" "CI_STEP_BUILD_DRY_RUN" \
        "$(var:l1 'CI_PIPELINE_RELEASE_DRY_RUN' 'CI_GLOBAL_DRY_RUN' 'false')"

      The status should be success
      The output should eq "false"
      The error should eq ''
    End

    It "Level 3 (Script) - script overrides all other levels"
      BeforeCall "export CI_GLOBAL_DRY_RUN='true'"
      BeforeCall "export CI_PIPELINE_RELEASE_DRY_RUN='true'"
      BeforeCall "export CI_STEP_BUILD_DRY_RUN='true'"
      BeforeCall "export CI_SCRIPT_DEPLOY_DRY_RUN='false'"

      When call var:l1 "CI_SCRIPT_DEPLOY_DRY_RUN" "CI_STEP_BUILD_DRY_RUN" \
        "$(var:l1 'CI_PIPELINE_RELEASE_DRY_RUN' 'CI_GLOBAL_DRY_RUN' 'false')"

      The status should be success
      The output should eq "false"
      The error should eq ''
    End

    It "Composable variable names from context - pipeline specific"
      # Dynamic composition: CI_PIPELINE_{pipeline_name}_{config_key}
      BeforeCall "export CI_GLOBAL_TIMEOUT='300'"
      BeforeCall "export CI_PIPELINE_TESTING_TIMEOUT='60'"
      BeforeCall "unset CI_STEP_LINT_TIMEOUT"
      BeforeCall "unset CI_SCRIPT_SHELLCHECK_TIMEOUT"

      test_ci_composable_pipeline() {
        local pipeline="testing"
        local step="lint"
        local script="shellcheck"
        local config_key="TIMEOUT"

        local pipeline_var="CI_PIPELINE_${pipeline^^}_${config_key}"
        local step_var="CI_STEP_${step^^}_${config_key}"
        local script_var="CI_SCRIPT_${script^^}_${config_key}"

        var:l1 "$script_var" "$step_var" \
          "$(var:l1 "$pipeline_var" "CI_GLOBAL_${config_key}" '300')"
      }
      When call test_ci_composable_pipeline

      The status should be success
      The output should eq "60"
      The error should eq ''
    End

    It "Composable variable names - step specific override"
      # Context: release pipeline, build step, docker script
      BeforeCall "export CI_GLOBAL_VERBOSE='false'"
      BeforeCall "export CI_PIPELINE_RELEASE_VERBOSE='false'"
      BeforeCall "export CI_STEP_BUILD_VERBOSE='true'"
      BeforeCall "unset CI_SCRIPT_DOCKER_VERBOSE"

      pipeline="release"
      step="build"
      script="docker"
      config_key="VERBOSE"

      pipeline_var="CI_PIPELINE_${pipeline^^}_${config_key}"
      step_var="CI_STEP_${step^^}_${config_key}"
      script_var="CI_SCRIPT_${script^^}_${config_key}"

      When call var:l1 "$script_var" "$step_var" \
        "$(var:l1 "$pipeline_var" "CI_GLOBAL_${config_key}" 'false')"

      The status should be success
      The output should eq "true"
      The error should eq ''
    End

    It "Multiple configuration keys - DRY_RUN, DEBUG, VERBOSE in same context"
      # Demonstrates that different config keys can have different override levels
      BeforeCall "export CI_GLOBAL_DRY_RUN='false'"
      BeforeCall "export CI_GLOBAL_DEBUG='false'"
      BeforeCall "export CI_GLOBAL_VERBOSE='false'"
      BeforeCall "export CI_PIPELINE_TESTING_DRY_RUN='true'"
      BeforeCall "export CI_STEP_UNIT_DEBUG='true'"
      BeforeCall "export CI_SCRIPT_PYTEST_VERBOSE='true'"

      test_ci_multiple_keys() {
        local pipeline="testing"
        local step="unit"
        local script="pytest"

        # DRY_RUN: override at pipeline level
        local dry_run=$(var:l1 "CI_SCRIPT_${script^^}_DRY_RUN" "CI_STEP_${step^^}_DRY_RUN" \
          "$(var:l1 "CI_PIPELINE_${pipeline^^}_DRY_RUN" 'CI_GLOBAL_DRY_RUN' 'false')")

        # DEBUG: override at step level
        local debug=$(var:l1 "CI_SCRIPT_${script^^}_DEBUG" "CI_STEP_${step^^}_DEBUG" \
          "$(var:l1 "CI_PIPELINE_${pipeline^^}_DEBUG" 'CI_GLOBAL_DEBUG' 'false')")

        # VERBOSE: override at script level
        local verbose=$(var:l1 "CI_SCRIPT_${script^^}_VERBOSE" "CI_STEP_${step^^}_VERBOSE" \
          "$(var:l1 "CI_PIPELINE_${pipeline^^}_VERBOSE" 'CI_GLOBAL_VERBOSE' 'false')")

        echo "$dry_run,$debug,$verbose"
      }
      When call test_ci_multiple_keys

      The status should be success
      The output should eq "true,true,true"
      The error should eq ''
    End

    It "Real-world scenario: exclude all steps except specific one"
      # Use case: Run only 'deploy' step in 'release' pipeline
      # Set global to skip everything, then enable only specific script
      BeforeCall "export CI_GLOBAL_SKIP='true'"
      BeforeCall "unset CI_PIPELINE_RELEASE_SKIP"
      BeforeCall "unset CI_STEP_DEPLOY_SKIP"
      BeforeCall "export CI_SCRIPT_K8S_DEPLOY_SKIP='false'"

      pipeline="release"
      step="deploy"
      script="k8s_deploy"
      config_key="SKIP"

      pipeline_var="CI_PIPELINE_${pipeline^^}_${config_key}"
      step_var="CI_STEP_${step^^}_${config_key}"
      script_var="CI_SCRIPT_${script^^}_${config_key}"

      When call var:l1 "$script_var" "$step_var" \
        "$(var:l1 "$pipeline_var" "CI_GLOBAL_${config_key}" 'false')"

      The status should be success
      The output should eq "false"
      The error should eq ''
    End

    It "Helper function pattern for CI config resolution"
      # Demonstrates a reusable helper pattern for resolving CI config
      BeforeCall "export CI_GLOBAL_RETRY_COUNT='3'"
      BeforeCall "export CI_PIPELINE_RELEASE_RETRY_COUNT='5'"
      BeforeCall "unset CI_STEP_DEPLOY_RETRY_COUNT"
      BeforeCall "unset CI_SCRIPT_HELM_RETRY_COUNT"

      # Helper function that takes context and config key
      ci_config() {
        local pipeline=$1
        local step=$2
        local script=$3
        local config_key=$4
        local default_value=${5:-""}

        local pipeline_var="CI_PIPELINE_${pipeline^^}_${config_key}"
        local step_var="CI_STEP_${step^^}_${config_key}"
        local script_var="CI_SCRIPT_${script^^}_${config_key}"
        local global_var="CI_GLOBAL_${config_key}"

        var:l1 "$script_var" "$step_var" \
          "$(var:l1 "$pipeline_var" "$global_var" "$default_value")"
      }

      When call ci_config "release" "deploy" "helm" "RETRY_COUNT" "1"

      The status should be success
      The output should eq "5"
      The error should eq ''
    End

    It "Complex scenario: multiple pipelines with different configurations"
      # Testing pipeline: fast, minimal retries
      # Release pipeline: thorough, more retries
      BeforeCall "export CI_GLOBAL_RETRY_COUNT='3'"
      BeforeCall "export CI_PIPELINE_TESTING_RETRY_COUNT='1'"
      BeforeCall "export CI_PIPELINE_RELEASE_RETRY_COUNT='5'"
      BeforeCall "unset CI_STEP_TEST_RETRY_COUNT"
      BeforeCall "unset CI_SCRIPT_PYTEST_RETRY_COUNT"

      test_ci_multiple_pipelines() {
        # Get retry count for testing pipeline
        local testing_retries=$(var:l1 "CI_SCRIPT_PYTEST_RETRY_COUNT" "CI_STEP_TEST_RETRY_COUNT" \
          "$(var:l1 'CI_PIPELINE_TESTING_RETRY_COUNT' 'CI_GLOBAL_RETRY_COUNT' '3')")

        # Get retry count for release pipeline
        local release_retries=$(var:l1 "CI_SCRIPT_PYTEST_RETRY_COUNT" "CI_STEP_TEST_RETRY_COUNT" \
          "$(var:l1 'CI_PIPELINE_RELEASE_RETRY_COUNT' 'CI_GLOBAL_RETRY_COUNT' '3')")

        echo "$testing_retries,$release_retries"
      }
      When call test_ci_multiple_pipelines

      The status should be success
      The output should eq "1,5"
      The error should eq ''
    End

    It "Strict naming convention enforcement through variable composition"
      # Ensures all variable names follow the strict pattern:
      # CI_{LEVEL}_{CONTEXT}_{CONFIG_KEY}
      BeforeCall "export CI_GLOBAL_MAX_PARALLEL='4'"
      BeforeCall "export CI_PIPELINE_CI_CD_MAX_PARALLEL='8'"
      BeforeCall "export CI_STEP_INTEGRATION_MAX_PARALLEL='2'"
      BeforeCall "unset CI_SCRIPT_API_TESTS_MAX_PARALLEL"

      # Context with underscore in name (ci_cd pipeline, api_tests script)
      pipeline="ci_cd"
      step="integration"
      script="api_tests"
      config_key="MAX_PARALLEL"

      # Variable names preserve underscores and use uppercase
      pipeline_var="CI_PIPELINE_${pipeline^^}_${config_key}"
      step_var="CI_STEP_${step^^}_${config_key}"
      script_var="CI_SCRIPT_${script^^}_${config_key}"

      When call var:l1 "$script_var" "$step_var" \
        "$(var:l1 "$pipeline_var" "CI_GLOBAL_${config_key}" '1')"

      The status should be success
      The output should eq "2"
      The error should eq ''
    End
  End

  Describe "time:diff /"
    # Mock time:now to return fixed timestamp
    Mock time:now
      echo "1609459200.500000"
    End

    It "calculates time difference correctly"
      When call time:diff "1609459199.000000"
      The output should eq "1.500000"
      The status should be success
    End

    It "handles same timestamps"
      When call time:diff "1609459200.500000"
      The output should eq "0"
      The status should be success
    End

    It "handles negative difference (earlier time)"
      When call time:diff "1609459201.000000"
      The output should eq "-.500000"
      The status should be success
    End

    It "handles zero start time"
      When call time:diff "0"
      The output should eq "1609459200.500000"
      The status should be success
    End

    It "handles decimal precision"
      When call time:diff "1609459200.123456"
      The output should eq ".376544"
      The status should be success
    End
  End

  Describe "confirm:by:input /"
    It "uses top priority value when provided"
      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      # Args: hint, variable, fallback, top, second, third, masked
      When call confirm:by:input "Prompt:" "result" "fallback" "top_value" "" "" ""

      The status should be success
      The variable RESULT should eq "top_value"
      The output should include "Prompt:"
      The output should include "top_value"
    End

    It "uses second priority value when top is empty"
      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call confirm:by:input "Prompt:" "result" "fallback" "" "second_value" "" ""

      The status should be success
      The variable RESULT should eq "second_value"
      The output should include "second_value"
    End

    It "uses third priority (fallback) when top and second are empty"
      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call confirm:by:input "Prompt:" "result" "fallback" "" "" "third_value" ""

      The status should be success
      The variable RESULT should eq "fallback"
      The output should include "fallback"
    End

    It "calls validate:input when no values provided (tests conditional logic)"
      # Mock validate:input to avoid interactive input
      validate:input() {
        eval "$1='validated_value'"
      }

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call confirm:by:input "Prompt:" "result" "fallback" "" "" "" ""

      The status should be success
      The variable RESULT should eq "validated_value"
    End

    It "calls validate:input:masked when masked flag is set (tests conditional logic)"
      # Mock validate:input:masked to avoid interactive input
      validate:input:masked() {
        eval "$1='masked_value'"
      }

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      # masked="true" (last param)
      When call confirm:by:input "Prompt:" "result" "fallback" "" "" "" "true"

      The status should be success
      The variable RESULT should eq "masked_value"
    End

    It "displays masked value in confirmation when masked flag set"
      When call confirm:by:input "Prompt:" "result" "fallback" "secret" "" "" "****"

      The status should be success
      The output should include "****"
      The output should not include "secret"
    End

    It "displays actual value when no masked flag"
      When call confirm:by:input "Prompt:" "result" "fallback" "actual_value" "" "" ""

      The status should be success
      The output should include "actual_value"
    End
  End

  Describe "validate:input:yn /"
    # macOS uses read -p which writes to terminal, not stdout (not captured by ShellSpec)
    is_macos() { [[ "$OSTYPE" == "darwin"* ]]; }
    Skip if "macOS read -p output not captured" is_macos

    It "returns true for 'y' input"
      Data
        #|y
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input:yn "result" "y" "Continue?"
      The status should be success
      The variable RESULT should eq "true"
      The output should include "Continue?"
    End

    It "returns true for 'Y' input (uppercase)"
      Data
        #|Y
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input:yn "result" "y" "Continue?"
      The status should be success
      The variable RESULT should eq "true"
      The output should include "Continue?"
    End

    It "returns true for 'yes' input"
      Data
        #|yes
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input:yn "result" "y" "Continue?"
      The status should be success
      The variable RESULT should eq "true"
      The output should include "Continue?"
    End

    It "returns true for 'YES' input (uppercase)"
      Data
        #|YES
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input:yn "result" "y" "Continue?"
      The status should be success
      The variable RESULT should eq "true"
      The output should include "Continue?"
    End

    It "returns false for 'n' input"
      Data
        #|n
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input:yn "result" "n" "Continue?"
      The status should be success
      The variable RESULT should eq "false"
      The output should include "Continue?"
    End

    It "returns false for 'no' input"
      Data
        #|no
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input:yn "result" "n" "Continue?"
      The status should be success
      The variable RESULT should eq "false"
      The output should include "Continue?"
    End

    It "returns false for any other input"
      Data
        #|maybe
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input:yn "result" "" "Continue?"
      The status should be success
      The variable RESULT should eq "false"
      The output should include "Continue?"
    End

    It "returns false for empty input"
      Data
        #|
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input:yn "result" "" "Continue?"
      The status should be success
      The variable RESULT should eq "false"
      The output should include "Continue?"
    End

    It "handles special characters in hint"
      Data
        #|y
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input:yn "result" "y" "Do you want to continue? (y/n)"
      The status should be success
      The variable RESULT should eq "true"
      The output should include "Do you want to continue? (y/n)"
    End
  End

  Describe "validate:input /"
    # macOS uses read -p which writes to terminal, not stdout (not captured by ShellSpec)
    is_macos() { [[ "$OSTYPE" == "darwin"* ]]; }
    Skip if "macOS read -p output not captured" is_macos

    It "reads and stores valid input"
      Data
        #|test_input
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" "Enter value:"
      The status should be success
      The variable RESULT should eq "test_input"
      The output should include "Enter value:"
    End

    It "accepts input with spaces"
      Data
        #|value with spaces
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" "Enter value:"
      The status should be success
      The variable RESULT should eq "value with spaces"
      The output should include "Enter value:"
    End

    It "accepts input with special characters"
      Data
        #|test@value#123
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" "Enter value:"
      The status should be success
      The variable RESULT should eq "test@value#123"
      The output should include "Enter value:"
    End

    It "loops until non-empty input (simulate empty then valid)"
      Data
        #|
        #|valid_input
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" "Enter value:"
      The status should be success
      The variable RESULT should eq "valid_input"
      The output should include "Enter value:"
    End

    It "rejects whitespace-only input and loops"
      Data
        #|   
        #|valid
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" "Enter value:"
      The status should be success
      The variable RESULT should eq "valid"
      The output should include "Enter value:"
    End

    It "displays hint when provided"
      Data
        #|test
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" "Please enter a value:"
      The status should be success
      The variable RESULT should eq "test"
      The output should include "Please enter a value:"
    End

    It "handles empty hint"
      Data
        #|test
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" ""
      The status should be success
      The variable RESULT should eq "test"
    End

    It "handles numeric input"
      Data
        #|12345
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" "Enter number:"
      The status should be success
      The variable RESULT should eq "12345"
      The output should include "Enter number:"
    End

    It "handles paths with slashes"
      Data
        #|/path/to/file.txt
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" "Enter path:"
      The status should be success
      The variable RESULT should eq "/path/to/file.txt"
      The output should include "Enter path:"
    End

    It "handles quoted strings"
      Data
        #|"quoted value"
      End

      preserve() { %preserve result:RESULT; }
      AfterCall preserve

      When call validate:input "result" "default" "Enter value:"
      The status should be success
      The variable RESULT should eq '"quoted value"'
      The output should include "Enter value:"
    End
  End

  Describe "to:slug /"
    It "Converts simple string to lowercase slug"
      When call to:slug "Hello World"

      The status should be success
      The output should eq "hello_world"
      The error should eq ''
    End

    It "Uses default separator underscore"
      When call to:slug "Test String"

      The status should be success
      The output should eq "test_string"
      The error should eq ''
    End

    It "Uses custom separator dash"
      When call to:slug "Test String" "-"

      The status should be success
      The output should eq "test-string"
      The error should eq ''
    End

    It "Uses custom separator dot"
      When call to:slug "Test String" "."

      The status should be success
      The output should eq "test.string"
      The error should eq ''
    End

    It "Removes special characters"
      When call to:slug "Hello@World#Test!"

      The status should be success
      The output should eq "hello_world_test"
      The error should eq ''
    End

    It "Cleans up repeated separators (underscores)"
      When call to:slug "Test__Multiple___Underscores" "_" 50

      The status should be success
      The output should eq "test_multiple_underscores"
      The error should eq ''
    End

    It "Cleans up repeated separators (dashes)"
      When call to:slug "Test--Multiple---Dashes" "-" 50

      The status should be success
      The output should eq "test-multiple-dashes"
      The error should eq ''
    End

    It "Cleans up mixed special characters creating repeated separators"
      When call to:slug "Test  !!  Multiple  @@  Separators" "_" 50

      The status should be success
      The output should eq "test_multiple_separators"
      The error should eq ''
    End

    It "Trims leading separators"
      When call to:slug "___Leading Underscores"

      The status should be success
      The output should eq "leading_underscores"
      The error should eq ''
    End

    It "Trims trailing separators"
      When call to:slug "Trailing Underscores___"

      The status should be success
      The output should eq "trailing_underscores"
      The error should eq ''
    End

    It "Trims leading and trailing separators"
      When call to:slug "___Both Sides___"

      The status should be success
      The output should eq "both_sides"
      The error should eq ''
    End

    It "Handles short strings within default trim length"
      When call to:slug "Short"

      The status should be success
      The output should eq "short"
      The error should eq ''
    End

    It "Uses default trim length of 20"
      When call to:slug "Exactly Twenty Chars"

      The status should be success
      The output should eq "exactly_twenty_chars"
      The error should eq ''
    End

    It "Trims long string and adds hash when exceeds default trim (20)"
      result=$(to:slug "This Is A Very Long String That Exceeds The Default Trim Length")
      When call echo "${#result}"

      The status should be success
      The output should eq "20"
      The error should eq ''
    End

    It "Trims long string with custom trim length of 30"
      result=$(to:slug "This Is A Very Long String That Should Be Trimmed" "_" 30)
      When call echo "${#result}"

      The status should be success
      The output should eq "30"
      The error should eq ''
    End

    It "Trims long string with custom trim length of 15"
      result=$(to:slug "Very Long String Needs Trimming" "_" 15)
      When call echo "${#result}"

      The status should be success
      The output should eq "15"
      The error should eq ''
    End

    It "Handles very small trim length (8 - minimum for hash)"
      result=$(to:slug "Long String" "_" 8)
      When call echo "${#result}"

      The status should be success
      The output should eq "8"
      The error should eq ''
    End

    It "Handles very small trim length (5 - less than hash size)"
      result=$(to:slug "Long String" "_" 5)
      When call echo "${#result}"

      The status should be success
      The output should eq "5"
      The error should eq ''
    End

    It "Produces consistent hash for same input"
      result1=$(to:slug "Very Long String That Needs Hashing" "_" 20)
      result2=$(to:slug "Very Long String That Needs Hashing" "_" 20)
      When call echo "$result1"

      The status should be success
      The output should eq "$result2"
      The error should eq ''
    End

    It "Produces different hash for different inputs"
      result1=$(to:slug "String One That Is Very Long" "_" 20)
      result2=$(to:slug "String Two That Is Very Long" "_" 20)
      test "$result1" != "$result2"
      When call echo $?

      The status should be success
      The output should eq "0"
      The error should eq ''
    End

    It "Handles empty string - generates hash-based slug with __ prefix"
      result=$(to:slug "")
      When call echo "${#result}"

      The status should be success
      The output should eq "9"
      The error should eq ''
    End

    It "Handles only special characters - generates hash-based slug with __ prefix"
      result=$(to:slug "!@#$%^&*()")
      When call echo "${#result}"

      The status should be success
      The output should eq "9"
      The error should eq ''
    End

    It "Handles only spaces - generates hash-based slug with __ prefix"
      result=$(to:slug "     ")
      When call echo "${#result}"

      The status should be success
      The output should eq "9"
      The error should eq ''
    End

    It "Hash-only slugs are unique for different inputs"
      result1=$(to:slug "!@#$%")
      result2=$(to:slug "^&*()")
      test "$result1" != "$result2"
      When call echo $?

      The status should be success
      The output should eq "0"
      The error should eq ''
    End

    It "Hash-only slugs are consistent for same input"
      result1=$(to:slug "!@#$%^&*()")
      result2=$(to:slug "!@#$%^&*()")
      When call echo "$result1"

      The status should be success
      The output should eq "$result2"
      The error should eq ''
    End

    It "Hash-only slug respects trim length"
      result=$(to:slug "!@#$%^&*()" "_" 5)
      When call echo "${#result}"

      The status should be success
      The output should eq "5"
      The error should eq ''
    End

    It "Handles mixed alphanumeric"
      When call to:slug "Test123String456"

      The status should be success
      The output should eq "test123string456"
      The error should eq ''
    End

    It "Handles numbers only"
      When call to:slug "1234567890"

      The status should be success
      The output should eq "1234567890"
      The error should eq ''
    End

    It "Preserves alphanumeric and converts rest to separator"
      When call to:slug "file-name_v1.2.3"

      The status should be success
      The output should eq "file_name_v1_2_3"
      The error should eq ''
    End

    It "Creates filesystem-safe filename from path-like string"
      When call to:slug "/path/to/some/file.txt" "_" 50

      The status should be success
      The output should eq "path_to_some_file_txt"
      The error should eq ''
    End

    It "Handles unicode/international characters (converts to separator)"
      When call to:slug "Héllo Wörld"

      The status should be success
      # International characters are treated as special chars and converted to separator
      The output should match pattern "*llo*rld"
      The error should eq ''
    End

    It "Real-world example: branch name to filename"
      When call to:slug "feature/add-new-api-endpoint" "_" 30

      The status should be success
      The output should eq "feature_add_new_api_endpoint"
      The error should eq ''
    End

    It "Real-world example: commit message to filename"
      result=$(to:slug "fix(core): resolve memory leak in parser" "-" 25)
      length=${#result}
      test $length -le 25
      When call echo $?

      The status should be success
      The output should eq "0"
      The error should eq ''
    End

    It "Real-world example: user input to safe filename"
      result=$(to:slug "My Important Document (Draft).pdf" "_" 20)
      When call echo "${#result}"

      The status should be success
      The output should eq "20"
      The error should eq ''
    End

    It "Hash is exactly 7 characters when used"
      result=$(to:slug "This Is A Very Long String That Will Definitely Need Hashing" "_" 20)
      hash_part=$(echo "$result" | rev | cut -d'_' -f1 | rev)
      When call echo "${#hash_part}"

      The status should be success
      The output should eq "7"
      The error should eq ''
    End

    It "Trimmed slug with hash has correct structure (prefix + separator + hash)"
      result=$(to:slug "Very Long String Needs Trimming And Hashing" "_" 20)
      # Should be: prefix (12 chars) + _ (1 char) + hash (7 chars) = 20 chars
      When call echo "${#result}"

      The status should be success
      The output should eq "20"
      The error should eq ''
    End

    It "Does not add hash when exactly at trim length"
      # Create a string that when slugified is exactly 18 chars (less than 20)
      result=$(to:slug "abcdefgh ijklmnopq" "_" 20)
      When call echo "${#result}"

      The status should be success
      The output should eq "18"
      The error should eq ''
    End

    It "Handles consecutive special characters between words"
      When call to:slug "Test!!!@@@###String"

      The status should be success
      The output should eq "test_string"
      The error should eq ''
    End

    It "Different separators produce different outputs"
      result1=$(to:slug "Hello World" "_")
      result2=$(to:slug "Hello World" "-")
      test "$result1" != "$result2"
      When call echo $?

      The status should be success
      The output should eq "0"
      The error should eq ''
    End

    It "Strategy 'always' - forces hash on short string"
      result=$(to:slug "hello" "_" "always")
      When call echo "${#result}"

      The status should be success
      The output should eq "13"  # hello (5) + _ (1) + hash (7)
      The error should eq ''
    End

    It "Strategy 'always' - forces hash on normal string"
      result=$(to:slug "Hello World" "_" "always")
      When call echo "${#result}"

      The status should be success
      The output should eq "19"  # hello_world (11) + _ (1) + hash (7) = 19
      The error should eq ''
    End

    It "Strategy 'always' - produces consistent hash"
      result1=$(to:slug "test string" "_" "always")
      result2=$(to:slug "test string" "_" "always")
      When call echo "$result1"

      The status should be success
      The output should eq "$result2"
      The error should eq ''
    End

    It "Strategy 'always' - produces different hashes for different inputs"
      result1=$(to:slug "string one" "_" "always")
      result2=$(to:slug "string two" "_" "always")
      test "$result1" != "$result2"
      When call echo $?

      The status should be success
      The output should eq "0"
      The error should eq ''
    End

    It "Strategy 'always' - works with custom separator"
      When call to:slug "hello world" "-" "always"

      The status should be success
      The output should match pattern "hello-world-*"
      The error should eq ''
    End

    It "Strategy 'always' - hash appended to slug (not trimmed)"
      result=$(to:slug "very long string that would normally be trimmed" "_" "always")
      # Should be full slug + _ + hash, not trimmed
      When call echo "$result"

      The status should be success
      The output should match pattern "very_long_string_that_would_normally_be_trimmed_*"
      The error should eq ''
    End

    It "Strategy 'always' - useful for URLs (deterministic cache keys)"
      url="https://api.example.com/v1/users"
      result=$(to:slug "$url" "_" "always")
      When call echo "$result"

      The status should be success
      The output should match pattern "https_api_example_com_v1_users_*"
      The error should eq ''
    End

    It "Strategy 'always' - different URLs produce different hashes"
      result1=$(to:slug "https://api.com/v1/users" "_" "always")
      result2=$(to:slug "https://api.com/v2/users" "_" "always")
      test "$result1" != "$result2"
      When call echo $?

      The status should be success
      The output should eq "0"
      The error should eq ''
    End

    It "Backwards compatibility - numeric trim still works"
      When call to:slug "Hello World" "_" 20

      The status should be success
      The output should eq "hello_world"
      The error should eq ''
    End

    It "Invalid trim parameter defaults to 20"
      result=$(to:slug "abcdefghij klmnop qrstuvwxyz" "_" "invalid")
      When call echo "${#result}"

      The status should be success
      The output should eq "20"
      The error should eq ''
    End
  End

  Describe "git:root /"
    # Dynamically determine the repo root for CI compatibility
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '/home/user/e-bash')"

    It "finds git repository root from current directory"
      When call git:root "."

      The status should be success
      The output should eq "$REPO_ROOT"
      The error should eq ''
    End

    It "resolves physical root when starting from symlinked path"
      tmp_dir=$(mktemp -d)
      ln -s "$REPO_ROOT" "$tmp_dir/repo-link"

      result=$(git:root "$tmp_dir/repo-link")
      rm -rf "$tmp_dir"

      When call echo "$result"

      The status should be success
      The output should eq "$REPO_ROOT"
      The error should eq ''
    End

    It "returns git repository type as 'regular' for normal repo"
      When call git:root "." "type"

      The status should be success
      The output should eq "regular"
      The error should eq ''
    End

    It "returns both type and path in 'both' mode"
      When call git:root "." "both"

      The status should be success
      The output should eq "regular:$REPO_ROOT"
      The error should eq ''
    End

    It "returns detailed info in 'all' mode"
      When call git:root "." "all"

      The status should be success
      The output should match pattern "regular:$REPO_ROOT:$REPO_ROOT/.git"
      The error should eq ''
    End

    It "finds git root from nested subdirectory"
      When call git:root "$REPO_ROOT/spec"

      The status should be success
      The output should eq "$REPO_ROOT"
      The error should eq ''
    End

    It "finds git root from deeply nested path"
      When call git:root "$REPO_ROOT/.scripts"

      The status should be success
      The output should eq "$REPO_ROOT"
      The error should eq ''
    End

    It "returns error when no git repo found"
      When call git:root "/tmp"

      The status should be failure
      The output should eq ""
      The error should eq ''
    End

    It "returns 'none' type when no git repo found"
      When call git:root "/tmp" "type"

      The status should be failure
      The output should eq "none"
      The error should eq ''
    End

    It "handles invalid starting path gracefully"
      When call git:root "/nonexistent/path"

      The status should be failure
      The output should eq ""
      The error should eq ''
    End

    It "uses current directory as default when no path provided"
      When call git:root

      The status should be success
      The output should eq "$REPO_ROOT"
      The error should eq ''
    End

    It "defaults to 'path' output type when invalid type provided"
      When call git:root "." "invalid_type"

      The status should be success
      The output should eq "$REPO_ROOT"
      The error should eq ''
    End
  End

  Describe "config:hierarchy /"
    # Dynamically determine the repo root for CI compatibility
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '/home/user/e-bash')"

    setup_test_configs() {
      local test_root="/tmp/config-hierarchy-test-$$"
      mkdir -p "$test_root/level1/level2/level3"
      test_root=$(cd "$test_root" && pwd -P)

      echo '{"root": true}' > "$test_root/.myconfig.json"
      echo '{"level1": true}' > "$test_root/level1/.myconfig.json"
      echo '{"level3": true}' > "$test_root/level1/level2/level3/.myconfig.json"

      echo "$test_root"
    }

    cleanup_test_configs() {
      local test_root="$1"
      rm -rf "$test_root"
    }

    It "finds config files in correct hierarchical order (root to current)"
      test_root=$(setup_test_configs)

      result=$(config:hierarchy ".myconfig" "$test_root/level1/level2/level3" "root" ".json")
      cleanup_test_configs "$test_root"

      line1=$(echo "$result" | sed -n '1p' | grep -o "\.myconfig\.json$")
      line2=$(echo "$result" | sed -n '2p' | grep -o "level1/\.myconfig\.json$")
      line3=$(echo "$result" | sed -n '3p' | grep -o "level3/\.myconfig\.json$")

      When call echo "$line1,$line2,$line3"

      The status should be success
      The output should eq ".myconfig.json,level1/.myconfig.json,level3/.myconfig.json"
    End

    It "finds .shellspec file in current repository"
      When call config:hierarchy ".shellspec" "." "git" ""

      The status should be success
      The output should eq "$REPO_ROOT/.shellspec"
      The error should eq ''
    End

    It "returns empty when no config files found"
      When call config:hierarchy "nonexistent.config" "/tmp" "root" ""

      The status should be failure
      The output should eq ""
      The error should eq ''
    End

    It "searches multiple config names (comma-separated)"
      test_root=$(setup_test_configs)
      echo '{"alt": true}' > "$test_root/level1/level2/level3/.altconfig.json"

      result=$(config:hierarchy ".myconfig,.altconfig" "$test_root/level1/level2/level3" "root" ".json")
      cleanup_test_configs "$test_root"
      count=$(count_lines "$result")

      When call echo "$count"

      The status should be success
      The output should eq "4"
    End

    It "tries multiple extensions for same config name"
      test_root=$(setup_test_configs)
      echo 'root: true' > "$test_root/.myconfig.yaml"

      result=$(config:hierarchy ".myconfig" "$test_root/level1/level2/level3" "root" ".json,.yaml")
      cleanup_test_configs "$test_root"

      has_json=$(count_matches "\.json$" "$result")
      has_yaml=$(count_matches "\.yaml$" "$result")

      When call echo "$has_json,$has_yaml"

      The status should be success
      The output should match pattern "*,1"
    End

    It "stops at git repository root by default"
      When call config:hierarchy ".shellspec" "." "git" ""

      The status should be success
      The output should eq "$REPO_ROOT/.shellspec"
    End

    It "stops at custom path when specified"
      test_root=$(setup_test_configs)

      result=$(config:hierarchy ".myconfig" "$test_root/level1/level2/level3" "$test_root/level1" ".json")
      cleanup_test_configs "$test_root"
      count=$(count_lines "$result")

      When call echo "$count"

      The status should be success
      The output should eq "2"  # Should find level1 and level3, but not root
    End

    It "handles invalid starting path gracefully"
      When call config:hierarchy ".config" "/nonexistent/path"

      The status should be failure
      The output should eq ""
    End

    It "uses current directory as default start path"
      When call config:hierarchy ".shellspec" "" "git" ""

      The status should be success
      The output should eq "$REPO_ROOT/.shellspec"
    End

    It "includes empty extension to match exact filename"
      test_root=$(setup_test_configs)
      echo '{"exact": true}' > "$test_root/level1/level2/level3/myconfig"

      result=$(config:hierarchy "myconfig" "$test_root/level1/level2/level3" "root" ",.json")
      cleanup_test_configs "$test_root"

      has_exact=$(count_matches "/myconfig$" "$result")

      When call echo "$has_exact"

      The status should be success
      The output should eq "1"
    End

    It "respects order: root configs first, current configs last"
      test_root=$(setup_test_configs)

      result=$(config:hierarchy ".myconfig" "$test_root/level1/level2/level3" "root" ".json")
      first_file=$(echo "$result" | head -n 1)
      last_file=$(echo "$result" | tail -n 1)
      cleanup_test_configs "$test_root"

      first_is_root=$(count_matches "^${test_root}/\.myconfig\.json$" "$first_file")
      last_is_level3=$(count_matches "level3/\.myconfig\.json$" "$last_file")

      When call echo "$first_is_root,$last_is_level3"

      The status should be success
      The output should eq "1,1"
    End

    It "handles whitespace in config names gracefully"
      test_root=$(setup_test_configs)

      result=$(config:hierarchy " .myconfig , .altconfig " "$test_root/level1/level2/level3" "root" ".json")
      cleanup_test_configs "$test_root"
      count=$(count_lines "$result")

      When call echo "$count"

      The status should be success
      The output should eq "3"
    End

    It "finds config files with default extensions when not specified"
      test_root=$(setup_test_configs)
      echo 'root: true' > "$test_root/.myconfig.yaml"
      echo 'root: true' > "$test_root/.myconfig.toml"

      result=$(config:hierarchy ".myconfig" "$test_root" "root")
      cleanup_test_configs "$test_root"
      count=$(count_lines "$result")

      # Helper function for numeric comparison
      check_count() { test "$1" -ge 3; }

      When call check_count "$count"

      The status should be success
    End
  End

  Describe "config:hierarchy:xdg /"
    setup_xdg_test() {
      local test_root="/tmp/xdg-test-$$"
      mkdir -p "$test_root/project/subdir"
      mkdir -p "$test_root/.config/myapp"
      mkdir -p "$test_root/etc/xdg/myapp"
      mkdir -p "$test_root/etc/myapp"

      # Hierarchical configs (highest priority)
      echo '{"level": "project"}' > "$test_root/project/myapp.json"
      echo '{"level": "subdir"}' > "$test_root/project/subdir/myapp.json"

      # XDG configs
      echo '{"level": "xdg_config_home"}' > "$test_root/.config/myapp/config.json"
      echo '{"level": "etc_xdg"}' > "$test_root/etc/xdg/myapp/config.json"
      echo '{"level": "etc"}' > "$test_root/etc/myapp/config.json"

      echo "$test_root"
    }

    cleanup_xdg_test() {
      local test_root="$1"
      rm -rf "$test_root"
    }

    # Helper wrapper for config:hierarchy:xdg with custom HOME
    call_xdg_with_home() {
      local home_dir="$1"
      shift
      local xdg_home=""
      local xdg_dirs=""
      local xdg_etc=""
      local xdg_dirs_set=0
      local xdg_etc_set=0
      if [[ "$1" == "--xdg" ]]; then
        xdg_home="$2"
        shift 2
      fi
      if [[ "$1" == "--xdg-dirs" ]]; then
        xdg_dirs="$2"
        xdg_dirs_set=1
        shift 2
      fi
      if [[ "$1" == "--xdg-etc" ]]; then
        xdg_etc="$2"
        xdg_etc_set=1
        shift 2
      fi

      local saved_home="$HOME"
      local saved_xdg="$XDG_CONFIG_HOME"
      local saved_xdg_dirs="$XDG_CONFIG_DIRS"
      local saved_xdg_etc="$XDG_ETC_DIR"
      export HOME="$home_dir"
      [[ -n "$xdg_home" ]] && export XDG_CONFIG_HOME="$xdg_home"
      if [[ $xdg_dirs_set -eq 1 ]]; then
        export XDG_CONFIG_DIRS="$xdg_dirs"
      fi
      if [[ $xdg_etc_set -eq 1 ]]; then
        export XDG_ETC_DIR="$xdg_etc"
      fi

      config:hierarchy:xdg "$@"
      local result=$?

      export HOME="$saved_home"
      export XDG_CONFIG_HOME="$saved_xdg"
      export XDG_CONFIG_DIRS="$saved_xdg_dirs"
      export XDG_ETC_DIR="$saved_xdg_etc"
      return $result
    }

    It "requires app_name as first argument"
      When call config:hierarchy:xdg "" "config"

      The status should be failure
      The error should include "ERROR: config:hierarchy:xdg requires app_name"
    End

    It "searches hierarchical paths with highest priority"
      test_root=$(setup_xdg_test)

      result=$(call_xdg_with_home "$test_root" "myapp" "myapp" "$test_root/project/subdir" "root" ".json")
      cleanup_xdg_test "$test_root"

      first_line=$(echo "$result" | head -n 1)
      has_subdir=$(count_matches "subdir/myapp.json" "$first_line")

      When call echo "$has_subdir"

      The status should be success
      The output should eq "1"
    End

    It "includes XDG config directories when they exist"
      test_root=$(setup_xdg_test)

      result=$(call_xdg_with_home "$test_root" "myapp" "config" "$test_root/project" "root" ".json")
      cleanup_xdg_test "$test_root"

      has_xdg=$(count_matches "\.config/myapp/config.json" "$result")

      When call echo "$has_xdg"

      The status should be success
      The output should eq "1"
    End

    It "searches XDG_CONFIG_HOME when set"
      test_root=$(setup_xdg_test)
      mkdir -p "$test_root/custom-xdg/myapp"
      echo '{"level": "custom"}' > "$test_root/custom-xdg/myapp/config.json"

      result=$(call_xdg_with_home "$test_root" --xdg "$test_root/custom-xdg" "myapp" "config" "$test_root/project" "root" ".json")
      cleanup_xdg_test "$test_root"

      has_custom_xdg=$(count_matches "custom-xdg/myapp/config.json" "$result")

      When call echo "$has_custom_xdg"

      The status should be success
      The output should eq "1"
    End

    It "avoids duplicates between hierarchical and XDG paths"
      test_root=$(setup_xdg_test)
      # Create same file in both hierarchical and XDG location
      mkdir -p "$test_root/.config/myapp"
      echo '{"level": "duplicate"}' > "$test_root/.config/myapp/config.json"
      echo '{"level": "duplicate"}' > "$test_root/project/config.json"

      BeforeCall "export HOME=$test_root"

      result=$(config:hierarchy:xdg "myapp" "config" "$test_root/project" "root" ".json")
      cleanup_xdg_test "$test_root"

      count=$(count_lines "$result")

      # Helper for comparison
      check_ge_1() { test "$1" -ge 1; }

      When call check_ge_1 "$count"

      The status should be success
    End

    It "searches multiple config names in XDG directories"
      test_root=$(setup_xdg_test)
      mkdir -p "$test_root/.config/myapp"
      echo '{"file": "config"}' > "$test_root/.config/myapp/config.json"
      echo '{"file": "myapprc"}' > "$test_root/.config/myapp/myapprc.json"

      result=$(call_xdg_with_home "$test_root" "myapp" "config,myapprc" "$test_root/project" "root" ".json")
      cleanup_xdg_test "$test_root"

      count=$(count_matches "\.config/myapp/" "$result")

      # Helper for comparison
      check_ge_2() { test "$1" -ge 2; }

      When call check_ge_2 "$count"

      The status should be success
    End

    It "respects priority order: hierarchy > XDG_CONFIG_HOME > ~/.config > /etc/xdg > /etc"
      test_root=$(setup_xdg_test)

      result=$(call_xdg_with_home "$test_root" --xdg-dirs "$test_root/etc/xdg" --xdg-etc "$test_root/etc" "myapp" "config" "$test_root/project" "root" ".json")
      cleanup_xdg_test "$test_root"

      # Helper to check priority order
      check_priority_order() {
        local result="$1"

        # Get line numbers of each config source
        local line_xdg_config line_etc_xdg line_etc
        line_xdg_config=$(echo "$result" | grep -n "\.config/myapp" | head -1 | cut -d: -f1)
        line_xdg_config=${line_xdg_config:-999}

        line_etc_xdg=$(echo "$result" | grep -n "etc/xdg/myapp" | head -1 | cut -d: -f1)
        line_etc_xdg=${line_etc_xdg:-999}

        line_etc=$(echo "$result" | grep -n "etc/myapp" | head -1 | cut -d: -f1)
        line_etc=${line_etc:-999}

        # XDG should come before etc/xdg which comes before etc
        if [[ "$line_xdg_config" -lt "$line_etc_xdg" ]] && [[ "$line_etc_xdg" -lt "$line_etc" ]]; then
          echo "0"
          return 0
        else
          echo "1"
          return 1
        fi
      }

      When call check_priority_order "$result"

      The status should be success
      The output should eq "0"
    End

    It "returns failure when no configs found anywhere"
      When call config:hierarchy:xdg "nonexistent-app" "nonexistent-config" "/tmp" "root" ""

      The status should be failure
      The output should eq ""
    End

    It "handles missing XDG directories gracefully"
      test_root=$(setup_xdg_test)
      # Remove XDG directories
      rm -rf "$test_root/.config"
      rm -rf "$test_root/etc"

      BeforeCall "export HOME=$test_root"

      result=$(config:hierarchy:xdg "myapp" "myapp" "$test_root/project/subdir" "root" ".json")
      cleanup_xdg_test "$test_root"

      # Should still find hierarchical configs
      count=$(count_lines "$result")

      # Helper for comparison
      check_ge_1() { test "$1" -ge 1; }

      When call check_ge_1 "$count"

      The status should be success
    End

    It "works with real-world app example: nvim"
      test_root=$(setup_xdg_test)
      mkdir -p "$test_root/.config/nvim"
      echo 'set number' > "$test_root/.config/nvim/init.vim"

      result=$(call_xdg_with_home "$test_root" "nvim" "init.vim" "$test_root/project" "home" "")
      cleanup_xdg_test "$test_root"

      has_nvim=$(count_matches "\.config/nvim/init.vim" "$result")

      When call echo "$has_nvim"

      The status should be success
      The output should eq "1"
    End

    It "uses default stop_at 'home' when not specified"
      test_root=$(setup_xdg_test)

      # Should stop at HOME by default, not search /etc
      result=$(call_xdg_with_home "$test_root" "myapp" "config" "$test_root/project" "" ".json")
      cleanup_xdg_test "$test_root"

      # XDG directories under HOME should still be searched
      has_xdg=$(count_matches "\.config/myapp" "$result")

      # Helper for comparison
      check_ge_0() { test "$1" -ge 0; }

      When call check_ge_0 "$has_xdg"

      The status should be success
    End
  End

  Describe "env:resolve /"
    It "resolves simple environment variable"
      BeforeCall "export TEST_VAR='hello'"
      When call env:resolve "Value: {{env.TEST_VAR}}"

      The status should be success
      The output should eq "Value: hello"
      The error should eq ''
    End

    It "resolves variable with no whitespace in pattern"
      BeforeCall "export MY_PATH='/usr/local/bin'"
      When call env:resolve "Path is: {{env.MY_PATH}}"

      The status should be success
      The output should eq "Path is: /usr/local/bin"
      The error should eq ''
    End

    It "resolves variable with whitespace before variable name"
      BeforeCall "export MY_VAR='test'"
      When call env:resolve "{{ env.MY_VAR }}"

      The status should be success
      The output should eq "test"
      The error should eq ''
    End

    It "resolves variable with multiple spaces before variable name"
      BeforeCall "export MY_VAR='value'"
      When call env:resolve "{{  env.MY_VAR  }}"

      The status should be success
      The output should eq "value"
      The error should eq ''
    End

    It "resolves variable with tabs and spaces"
      BeforeCall "export TEST_VAR='result'"
      When call env:resolve "{{   env.TEST_VAR   }}"

      The status should be success
      The output should eq "result"
      The error should eq ''
    End

    It "resolves multiple variables in one string"
      BeforeCall "export VAR1='first'"
      BeforeCall "export VAR2='second'"
      When call env:resolve "{{env.VAR1}} and {{env.VAR2}}"

      The status should be success
      The output should eq "first and second"
      The error should eq ''
    End

    It "resolves three variables in one string"
      BeforeCall "export A='alpha'"
      BeforeCall "export B='beta'"
      BeforeCall "export C='gamma'"
      When call env:resolve "{{env.A}}-{{env.B}}-{{env.C}}"

      The status should be success
      The output should eq "alpha-beta-gamma"
      The error should eq ''
    End

    It "resolves variables with mixed whitespace"
      BeforeCall "export VAR1='one'"
      BeforeCall "export VAR2='two'"
      When call env:resolve "{{env.VAR1}} {{ env.VAR2 }} {{  env.VAR1  }}"

      The status should be success
      The output should eq "one two one"
      The error should eq ''
    End

    It "returns empty string for unset variable"
      BeforeCall "unset UNSET_VAR"
      When call env:resolve "Value: {{env.UNSET_VAR}}"

      The status should be success
      The output should eq "Value: "
      The error should eq ''
    End

    It "returns empty string for empty variable"
      BeforeCall "export EMPTY_VAR=''"
      When call env:resolve "Value: {{env.EMPTY_VAR}}"

      The status should be success
      The output should eq "Value: "
      The error should eq ''
    End

    It "handles path expansion with HOME"
      BeforeCall "export HOME='/home/user'"
      When call env:resolve "{{env.HOME}}/config"

      The status should be success
      The output should eq "/home/user/config"
      The error should eq ''
    End

    It "handles special characters in variable value"
      BeforeCall "export SPECIAL='test@value#123'"
      When call env:resolve "{{env.SPECIAL}}"

      The status should be success
      The output should eq "test@value#123"
      The error should eq ''
    End

    It "handles spaces in variable value"
      BeforeCall "export SPACED='value with spaces'"
      When call env:resolve "Result: {{env.SPACED}}"

      The status should be success
      The output should eq "Result: value with spaces"
      The error should eq ''
    End

    It "handles slashes in variable value (paths)"
      BeforeCall "export FILE_PATH='/path/to/file.txt'"
      When call env:resolve "File: {{env.FILE_PATH}}"

      The status should be success
      The output should eq "File: /path/to/file.txt"
      The error should eq ''
    End

    It "handles variable names with underscores"
      BeforeCall "export MY_LONG_VAR_NAME='test'"
      When call env:resolve "{{env.MY_LONG_VAR_NAME}}"

      The status should be success
      The output should eq "test"
      The error should eq ''
    End

    It "handles variable names with numbers"
      BeforeCall "export VAR123='numeric'"
      When call env:resolve "{{env.VAR123}}"

      The status should be success
      The output should eq "numeric"
      The error should eq ''
    End

    It "handles mixed underscores and numbers in variable names"
      BeforeCall "export MY_VAR_123_TEST='complex'"
      When call env:resolve "{{env.MY_VAR_123_TEST}}"

      The status should be success
      The output should eq "complex"
      The error should eq ''
    End

    It "preserves text outside of patterns"
      BeforeCall "export VAR='value'"
      When call env:resolve "before {{env.VAR}} after"

      The status should be success
      The output should eq "before value after"
      The error should eq ''
    End

    It "returns input unchanged when no patterns present"
      When call env:resolve "no patterns here"

      The status should be success
      The output should eq "no patterns here"
      The error should eq ''
    End

    It "handles empty string input"
      When call env:resolve ""

      The status should be success
      The output should eq ""
      The error should eq ''
    End

    It "handles string with only pattern"
      BeforeCall "export ONLY='value'"
      When call env:resolve "{{env.ONLY}}"

      The status should be success
      The output should eq "value"
      The error should eq ''
    End

    It "handles multiline variable values"
      BeforeCall "export MULTILINE='line1
line2'"
      When call env:resolve "{{env.MULTILINE}}"

      The status should be success
      The output should eq "line1
line2"
      The error should eq ''
    End

    It "handles numeric variable values"
      BeforeCall "export NUMBER='12345'"
      When call env:resolve "Count: {{env.NUMBER}}"

      The status should be success
      The output should eq "Count: 12345"
      The error should eq ''
    End

    It "handles consecutive patterns"
      BeforeCall "export A='1'"
      BeforeCall "export B='2'"
      When call env:resolve "{{env.A}}{{env.B}}"

      The status should be success
      The output should eq "12"
      The error should eq ''
    End

    It "handles pattern at start of string"
      BeforeCall "export VAR='start'"
      When call env:resolve "{{env.VAR}} rest of string"

      The status should be success
      The output should eq "start rest of string"
      The error should eq ''
    End

    It "handles pattern at end of string"
      BeforeCall "export VAR='end'"
      When call env:resolve "start of string {{env.VAR}}"

      The status should be success
      The output should eq "start of string end"
      The error should eq ''
    End

    It "handles complex real-world example: config file path"
      BeforeCall "export CONFIG_DIR='/etc/myapp'"
      BeforeCall "export ENV='production'"
      When call env:resolve "{{env.CONFIG_DIR}}/config.{{env.ENV}}.json"

      The status should be success
      The output should eq "/etc/myapp/config.production.json"
      The error should eq ''
    End

    It "handles URL construction"
      BeforeCall "export API_HOST='api.example.com'"
      BeforeCall "export API_VERSION='v1'"
      When call env:resolve "https://{{env.API_HOST}}/{{env.API_VERSION}}/users"

      The status should be success
      The output should eq "https://api.example.com/v1/users"
      The error should eq ''
    End

    It "does not resolve invalid pattern (missing env prefix)"
      BeforeCall "export VAR='value'"
      When call env:resolve "{{VAR}}"

      The status should be success
      The output should eq "{{VAR}}"
      The error should eq ''
    End

    It "does not resolve pattern with invalid variable name (starts with number)"
      # No BeforeCall needed - variable names starting with numbers are invalid in bash
      # Our regex pattern won't match this, so it should be left unchanged
      When call env:resolve "{{env.123VAR}}"

      The status should be success
      # Should not resolve because variable names can't start with numbers
      The output should eq "{{env.123VAR}}"
      The error should eq ''
    End

    It "handles pattern with dash (not resolved - invalid variable name)"
      When call env:resolve "{{env.MY-VAR}}"

      The status should be success
      # Dash is not valid in bash variable names, so pattern is not resolved
      The output should eq "{{env.MY-VAR}}"
      The error should eq ''
    End

    It "resolves same variable multiple times"
      BeforeCall "export REPEAT='test'"
      When call env:resolve "{{env.REPEAT}} and {{env.REPEAT}} and {{env.REPEAT}}"

      The status should be success
      The output should eq "test and test and test"
      The error should eq ''
    End

    It "handles quoted values in environment variables"
      BeforeCall "export QUOTED='\"quoted value\"'"
      When call env:resolve "{{env.QUOTED}}"

      The status should be success
      The output should eq '"quoted value"'
      The error should eq ''
    End

    It "handles dollar signs in variable values"
      BeforeCall "export DOLLAR='$100'"
      When call env:resolve "Price: {{env.DOLLAR}}"

      The status should be success
      The output should eq "Price: $100"
      The error should eq ''
    End

    It "handles backslashes in variable values"
      BeforeCall "export BACKSLASH='C:\path\to\file'"
      When call env:resolve "{{env.BACKSLASH}}"

      The status should be success
      The output should eq 'C:\path\to\file'
      The error should eq ''
    End

    It "real-world use case: CI/CD mode resolution"
      BeforeCall "export CI_MODE='staging'"
      BeforeCall "export DRY_RUN='true'"
      When call env:resolve "Running in {{env.CI_MODE}} mode with dry_run={{env.DRY_RUN}}"

      The status should be success
      The output should eq "Running in staging mode with dry_run=true"
      The error should eq ''
    End

    Describe "Associative array support /"
      It "resolves variable from associative array"
        setup_array() {
          declare -gA TEST_ARRAY
          TEST_ARRAY[API_HOST]="api.example.com"
        }
        BeforeCall setup_array

        When call env:resolve "Host: {{env.API_HOST}}" "TEST_ARRAY"

        The status should be success
        The output should eq "Host: api.example.com"
        The error should eq ''
      End

      It "resolves multiple variables from associative array"
        setup_array() {
          declare -gA CONFIG
          CONFIG[API_HOST]="api.example.com"
          CONFIG[VERSION]="v2"
          CONFIG[PORT]="8080"
        }
        BeforeCall setup_array

        When call env:resolve "https://{{env.API_HOST}}:{{env.PORT}}/{{env.VERSION}}/users" "CONFIG"

        The status should be success
        The output should eq "https://api.example.com:8080/v2/users"
        The error should eq ''
      End

      It "falls back to environment variable when not in array"
        setup_array() {
          declare -gA PARTIAL_CONFIG
          PARTIAL_CONFIG[API_HOST]="api.example.com"
        }
        BeforeCall setup_array
        BeforeCall "export PORT='3000'"

        When call env:resolve "{{env.API_HOST}}:{{env.PORT}}" "PARTIAL_CONFIG"

        The status should be success
        The output should eq "api.example.com:3000"
        The error should eq ''
      End

      It "array value takes priority over environment variable"
        setup_array() {
          declare -gA OVERRIDE_CONFIG
          OVERRIDE_CONFIG[PATH]="/custom/path"
        }
        BeforeCall setup_array
        BeforeCall "export PATH='/usr/bin'"

        When call env:resolve "{{env.PATH}}" "OVERRIDE_CONFIG"

        The status should be success
        The output should eq "/custom/path"
        The error should eq ''
      End

      It "handles empty value in associative array"
        setup_array() {
          declare -gA EMPTY_CONFIG
          EMPTY_CONFIG[EMPTY_VAR]=""
        }
        BeforeCall setup_array

        When call env:resolve "Value: {{env.EMPTY_VAR}}" "EMPTY_CONFIG"

        The status should be success
        The output should eq "Value: "
        The error should eq ''
      End

      It "handles non-existent array gracefully"
        BeforeCall "export FALLBACK='value'"

        When call env:resolve "{{env.FALLBACK}}" "NONEXISTENT_ARRAY"

        The status should be success
        The output should eq "value"
        The error should eq ''
      End

      It "handles regular array (not associative) gracefully"
        setup_array() {
          declare -ga REGULAR_ARRAY
          REGULAR_ARRAY=(one two three)
        }
        BeforeCall setup_array
        BeforeCall "export VAR='env_value'"

        When call env:resolve "{{env.VAR}}" "REGULAR_ARRAY"

        The status should be success
        The output should eq "env_value"
        The error should eq ''
      End

      It "handles array with special characters in values"
        setup_array() {
          declare -gA SPECIAL_CONFIG
          SPECIAL_CONFIG[URL]="https://example.com/path?query=value&foo=bar"
          SPECIAL_CONFIG[QUOTED]='"quoted value"'
        }
        BeforeCall setup_array

        When call env:resolve "{{env.URL}} - {{env.QUOTED}}" "SPECIAL_CONFIG"

        The status should be success
        The output should eq 'https://example.com/path?query=value&foo=bar - "quoted value"'
        The error should eq ''
      End

      It "real-world: template rendering with config array"
        setup_config() {
          declare -gA DEPLOY_CONFIG
          DEPLOY_CONFIG[ENVIRONMENT]="production"
          DEPLOY_CONFIG[REGION]="us-east-1"
          DEPLOY_CONFIG[CLUSTER]="main-cluster"
          DEPLOY_CONFIG[REPLICAS]="3"
        }
        BeforeCall setup_config

        When call env:resolve "Deploy to {{env.ENVIRONMENT}} in {{env.REGION}} ({{env.CLUSTER}}, replicas={{env.REPLICAS}})" "DEPLOY_CONFIG"

        The status should be success
        The output should eq "Deploy to production in us-east-1 (main-cluster, replicas=3)"
        The error should eq ''
      End
    End

    Describe "Pipeline mode /"
      It "resolves variables from stdin (single line)"
        Data
          #|{{env.TEST_VAR}}
        End
        BeforeCall "export TEST_VAR='piped_value'"

        When call env:resolve

        The status should be success
        The output should eq "piped_value"
        The error should eq ''
      End

      It "resolves variables from stdin (multiple lines)"
        Data
          #|Line 1: {{env.VAR1}}
          #|Line 2: {{env.VAR2}}
          #|Line 3: {{env.VAR3}}
        End
        BeforeCall "export VAR1='first'"
        BeforeCall "export VAR2='second'"
        BeforeCall "export VAR3='third'"

        When call env:resolve

        The status should be success
        The line 1 of output should eq "Line 1: first"
        The line 2 of output should eq "Line 2: second"
        The line 3 of output should eq "Line 3: third"
        The error should eq ''
      End

      It "pipeline mode with associative array"
        Data
          #|{{env.API_HOST}}/{{env.VERSION}}
        End
        setup_array() {
          declare -gA PIPE_CONFIG
          PIPE_CONFIG[API_HOST]="api.example.com"
          PIPE_CONFIG[VERSION]="v3"
        }
        BeforeCall setup_array

        When call env:resolve "PIPE_CONFIG"

        The status should be success
        The output should eq "api.example.com/v3"
        The error should eq ''
      End

      It "pipeline mode with array fallback to env"
        Data
          #|{{env.FROM_ARRAY}} and {{env.FROM_ENV}}
        End
        setup_array() {
          declare -gA MIXED_CONFIG
          MIXED_CONFIG[FROM_ARRAY]="array_value"
        }
        BeforeCall setup_array
        BeforeCall "export FROM_ENV='env_value'"

        When call env:resolve "MIXED_CONFIG"

        The status should be success
        The output should eq "array_value and env_value"
        The error should eq ''
      End

      It "pipeline mode preserves empty lines"
        Data
          #|{{env.VAR1}}
          #|
          #|{{env.VAR2}}
        End
        BeforeCall "export VAR1='first'"
        BeforeCall "export VAR2='second'"

        When call env:resolve

        The status should be success
        The line 1 of output should eq "first"
        The line 2 of output should eq ""
        The line 3 of output should eq "second"
        The error should eq ''
      End

      It "pipeline mode handles lines without patterns"
        Data
          #|Plain text line
          #|{{env.VAR}} with pattern
          #|Another plain line
        End
        BeforeCall "export VAR='value'"

        When call env:resolve

        The status should be success
        The line 1 of output should eq "Plain text line"
        The line 2 of output should eq "value with pattern"
        The line 3 of output should eq "Another plain line"
        The error should eq ''
      End

      It "real-world: process config file template"
        Data
          #|server:
          #|  host: {{env.SERVER_HOST}}
          #|  port: {{env.SERVER_PORT}}
          #|database:
          #|  url: {{env.DB_URL}}
        End
        BeforeCall "export SERVER_HOST='localhost'"
        BeforeCall "export SERVER_PORT='8080'"
        BeforeCall "export DB_URL='postgresql://localhost/mydb'"

        When call env:resolve

        The status should be success
        The line 1 of output should eq "server:"
        The line 2 of output should eq "  host: localhost"
        The line 3 of output should eq "  port: 8080"
        The line 4 of output should eq "database:"
        The line 5 of output should eq "  url: postgresql://localhost/mydb"
        The error should eq ''
      End

      It "real-world: process Dockerfile template with array"
        Data
          #|FROM {{env.BASE_IMAGE}}
          #|ENV APP_VERSION={{env.VERSION}}
          #|EXPOSE {{env.PORT}}
        End
        setup_docker_vars() {
          declare -gA DOCKER_VARS
          DOCKER_VARS[BASE_IMAGE]="node:18-alpine"
          DOCKER_VARS[VERSION]="1.2.3"
          DOCKER_VARS[PORT]="3000"
        }
        BeforeCall setup_docker_vars

        When call env:resolve "DOCKER_VARS"

        The status should be success
        The line 1 of output should eq "FROM node:18-alpine"
        The line 2 of output should eq "ENV APP_VERSION=1.2.3"
        The line 3 of output should eq "EXPOSE 3000"
        The error should eq ''
      End
    End

    Describe "Special character escaping and safety /"
      It "handles ampersand (&) in variable values"
        BeforeCall "export URL='https://example.com/api?a=1&b=2&c=3'"
        When call env:resolve "URL: {{env.URL}}"

        The status should be success
        The output should eq "URL: https://example.com/api?a=1&b=2&c=3"
        The error should eq ''
      End

      It "handles multiple ampersands in URL query parameters"
        BeforeCall "export QUERY='param1=value1&param2=value2&param3=value3'"
        When call env:resolve "Query: {{env.QUERY}}"

        The status should be success
        The output should eq "Query: param1=value1&param2=value2&param3=value3"
        The error should eq ''
      End

      It "handles backslash in variable values"
        BeforeCall "export WIN_PATH='C:\Users\Admin\Documents'"
        When call env:resolve "Path: {{env.WIN_PATH}}"

        The status should be success
        The output should eq 'Path: C:\Users\Admin\Documents'
        The error should eq ''
      End

      It "handles both backslash and ampersand together"
        BeforeCall "export MIXED='C:\Path\file.txt?query=a&b=c'"
        When call env:resolve "Mixed: {{env.MIXED}}"

        The status should be success
        The output should eq 'Mixed: C:\Path\file.txt?query=a&b=c'
        The error should eq ''
      End

      It "handles ampersand at start and end of value"
        BeforeCall "export AMP_EDGES='&start_and_end&'"
        When call env:resolve "Value: {{env.AMP_EDGES}}"

        The status should be success
        The output should eq "Value: &start_and_end&"
        The error should eq ''
      End

      It "handles backslash at end of value"
        BeforeCall "export TRAILING_SLASH='path\with\trailing\'"
        When call env:resolve "Path: {{env.TRAILING_SLASH}}"

        The status should be success
        The output should eq 'Path: path\with\trailing\'
        The error should eq ''
      End

      It "handles escaped characters in array values"
        setup_array() {
          declare -gA SPECIAL_CHARS
          SPECIAL_CHARS[URL]="https://api.com?token=abc&user=xyz"
          SPECIAL_CHARS[PATH]='C:\Program Files\App'
        }
        BeforeCall setup_array

        When call env:resolve "{{env.URL}} - {{env.PATH}}" "SPECIAL_CHARS"

        The status should be success
        The output should eq 'https://api.com?token=abc&user=xyz - C:\Program Files\App'
        The error should eq ''
      End

      It "detects direct self-referential pattern"
        BeforeCall "export SELF_REF='{{env.SELF_REF}}'"
        When call env:resolve "Value: {{env.SELF_REF}}"

        The status should be failure
        The error should include "self-referential pattern"
      End

      It "detects indirect self-referential pattern (cycle)"
        BeforeCall "export A='{{env.B}}'"
        BeforeCall "export B='{{env.A}}'"
        When call env:resolve "Value: {{env.A}}"

        The status should be failure
        The error should include "exceeded maximum iterations"
      End

      It "handles nested patterns (A->B->value)"
        BeforeCall "export INNER='final_value'"
        BeforeCall "export OUTER='{{env.INNER}}'"
        When call env:resolve "Value: {{env.OUTER}}"

        The status should be success
        The output should eq "Value: final_value"
        The error should eq ''
      End

      It "handles deep nesting without cycles"
        BeforeCall "export L0='value'"
        BeforeCall "export L1='{{env.L0}}'"
        BeforeCall "export L2='{{env.L1}}'"
        BeforeCall "export L3='{{env.L2}}'"
        When call env:resolve "Deep: {{env.L3}}"

        The status should be success
        The output should eq "Deep: value"
        The error should eq ''
      End

      It "stops at max iterations for complex cycles"
        # Create a longer cycle: A->B->C->D->E->A
        BeforeCall "export CYCLE_A='{{env.CYCLE_B}}'"
        BeforeCall "export CYCLE_B='{{env.CYCLE_C}}'"
        BeforeCall "export CYCLE_C='{{env.CYCLE_D}}'"
        BeforeCall "export CYCLE_D='{{env.CYCLE_E}}'"
        BeforeCall "export CYCLE_E='{{env.CYCLE_A}}'"

        When call env:resolve "Cycle: {{env.CYCLE_A}}"

        The status should be failure
        The error should include "exceeded maximum iterations"
      End

      It "handles self-referential pattern in array"
        setup_array() {
          declare -gA BAD_CONFIG
          BAD_CONFIG[SELF]='{{env.SELF}}'
        }
        BeforeCall setup_array

        When call env:resolve "Value: {{env.SELF}}" "BAD_CONFIG"

        The status should be failure
        The error should include "self-referential pattern"
      End

      It "real-world: URL with query parameters and fragments"
        BeforeCall "export API_URL='https://api.example.com/v1/users?sort=name&filter=active#results'"
        When call env:resolve "API: {{env.API_URL}}"

        The status should be success
        The output should eq "API: https://api.example.com/v1/users?sort=name&filter=active#results"
        The error should eq ''
      End

      It "real-world: Windows registry path"
        BeforeCall "export REG_PATH='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion'"
        When call env:resolve "Registry: {{env.REG_PATH}}"

        The status should be success
        The output should eq 'Registry: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion'
        The error should eq ''
      End

      It "real-world: sed command with ampersand"
        BeforeCall "export SED_REPL='s/old/& new/g'"
        When call env:resolve "Command: {{env.SED_REPL}}"

        The status should be success
        The output should eq "Command: s/old/& new/g"
        The error should eq ''
      End
    End
  End
End
