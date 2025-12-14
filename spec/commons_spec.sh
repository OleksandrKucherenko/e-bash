#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2288

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-14
## Version: 1.0.0
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
      When call to:slug "Test  !!  Multiple  @@  Separators"

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
      When call to:slug "This Is A Very Long String That Exceeds The Default Trim Length"

      The status should be success
      The output should match pattern "this_is_a_ve_*"
      The output should satisfy "[ ${#STDOUT} -eq 20 ]"
      The error should eq ''
    End

    It "Trims long string with custom trim length of 30"
      When call to:slug "This Is A Very Long String That Should Be Trimmed" "_" 30

      The status should be success
      The output should match pattern "this_is_a_very_long_st_*"
      The output should satisfy "[ ${#STDOUT} -eq 30 ]"
      The error should eq ''
    End

    It "Trims long string with custom trim length of 15"
      When call to:slug "Very Long String Needs Trimming" "_" 15

      The status should be success
      The output should satisfy "[ ${#STDOUT} -eq 15 ]"
      The error should eq ''
    End

    It "Handles very small trim length (8 - minimum for hash)"
      When call to:slug "Long String" "_" 8

      The status should be success
      The output should satisfy "[ ${#STDOUT} -eq 8 ]"
      The error should eq ''
    End

    It "Handles very small trim length (5 - less than hash size)"
      When call to:slug "Long String" "_" 5

      The status should be success
      The output should satisfy "[ ${#STDOUT} -eq 5 ]"
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
      When call to:slug ""

      The status should be success
      The output should match pattern "__*"
      The output should satisfy "[ ${#STDOUT} -eq 9 ]"
      The error should eq ''
    End

    It "Handles only special characters - generates hash-based slug with __ prefix"
      When call to:slug "!@#$%^&*()"

      The status should be success
      The output should match pattern "__*"
      The output should satisfy "[ ${#STDOUT} -eq 9 ]"
      The error should eq ''
    End

    It "Handles only spaces - generates hash-based slug with __ prefix"
      When call to:slug "     "

      The status should be success
      The output should match pattern "__*"
      The output should satisfy "[ ${#STDOUT} -eq 9 ]"
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
      When call to:slug "!@#$%^&*()" "_" 5

      The status should be success
      The output should satisfy "[ ${#STDOUT} -eq 5 ]"
      The output should match pattern "__*"
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
      When call to:slug "/path/to/some/file.txt"

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
      When call to:slug "fix(core): resolve memory leak in parser" "-" 25

      The status should be success
      The output should satisfy "[ ${#STDOUT} -le 25 ]"
      The error should eq ''
    End

    It "Real-world example: user input to safe filename"
      When call to:slug "My Important Document (Draft).pdf" "_" 20

      The status should be success
      The output should satisfy "[ ${#STDOUT} -eq 20 ]"
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
      When call echo "$result"

      The status should be success
      The output should satisfy "[ ${#STDOUT} -eq 20 ]"
      The output should match pattern "*_*"
      The error should eq ''
    End

    It "Does not add hash when exactly at trim length"
      # Create a string that when slugified is exactly 20 chars
      When call to:slug "abcdefgh ijklmnopq" "_" 20

      The status should be success
      The output should eq "abcdefgh_ijklmnopq"
      The output should satisfy "[ ${#STDOUT} -eq 18 ]"
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
  End
End
