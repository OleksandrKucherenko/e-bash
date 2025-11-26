# Pester CI/CD Integration

## Table of Contents
1. [Complete Pester Configuration](#complete-pester-configuration)
2. [GitHub Actions](#github-actions)
3. [Azure DevOps](#azure-devops)
4. [GitLab CI](#gitlab-ci)
5. [Jenkins](#jenkins)
6. [Reusable Runner Script](#reusable-runner-script)

---

## Complete Pester Configuration

```powershell
$config = New-PesterConfiguration

# Test discovery and execution
$config.Run.Path = './tests'
$config.Run.Exit = $true                    # Exit code for CI (0=pass, 1=fail)
$config.Run.PassThru = $true                # Return result object

# Filtering
$config.Filter.Tag = @('Unit')              # Only run tagged tests
$config.Filter.ExcludeTag = @('Slow')       # Exclude slow tests
$config.Filter.FullName = '*Get-Widget*'    # Name pattern filter

# Test results (JUnit/NUnit)
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'JUnitXml'  # JUnitXml, NUnitXml, NUnit2.5, NUnit3
$config.TestResult.OutputPath = 'test-results.xml'
$config.TestResult.TestSuiteName = 'MyProject'

# Code coverage
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = './src'
$config.CodeCoverage.OutputFormat = 'JaCoCo'  # JaCoCo, CoverageGutters, Cobertura
$config.CodeCoverage.OutputPath = 'coverage.xml'
$config.CodeCoverage.CoveragePercentTarget = 80
$config.CodeCoverage.ExcludeTests = $true

# Output formatting
$config.Output.Verbosity = 'Detailed'         # None, Normal, Detailed, Diagnostic
$config.Output.RenderMode = 'Plaintext'       # Plaintext, Ansi, ConsoleColor, Auto
$config.Output.CIFormat = 'GithubActions'     # GithubActions, AzureDevops, None

Invoke-Pester -Configuration $config
```

---

## GitHub Actions

```yaml
name: PowerShell Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest  # or windows-latest, macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Install Pester
      shell: pwsh
      run: |
        Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0

    - name: Run Pester Tests
      shell: pwsh
      run: |
        $config = New-PesterConfiguration
        $config.Run.Path = './tests'
        $config.Run.Exit = $true
        $config.Output.CIFormat = 'GithubActions'
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'JUnitXml'
        $config.TestResult.OutputPath = 'test-results.xml'
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = './src'
        $config.CodeCoverage.OutputPath = 'coverage.xml'
        Invoke-Pester -Configuration $config

    - name: Publish Test Results
      uses: dorny/test-reporter@v1
      if: always()
      with:
        name: Pester Tests
        path: test-results.xml
        reporter: java-junit

    - name: Upload Coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        files: coverage.xml
        fail_ci_if_error: true
```

---

## Azure DevOps

```yaml
trigger:
  - main

pool:
  vmImage: 'windows-latest'

steps:
- task: PowerShell@2
  displayName: 'Install Pester'
  inputs:
    targetType: 'inline'
    script: |
      Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0

- task: PowerShell@2
  displayName: 'Run Pester Tests'
  inputs:
    targetType: 'inline'
    script: |
      $config = New-PesterConfiguration
      $config.Run.Path = './tests'
      $config.Output.CIFormat = 'AzureDevops'
      $config.TestResult.Enabled = $true
      $config.TestResult.OutputFormat = 'NUnitXml'
      $config.TestResult.OutputPath = '$(System.DefaultWorkingDirectory)/Test-Results.xml'
      $config.CodeCoverage.Enabled = $true
      $config.CodeCoverage.Path = './src'
      $config.CodeCoverage.OutputPath = '$(System.DefaultWorkingDirectory)/coverage.xml'
      Invoke-Pester -Configuration $config

- task: PublishTestResults@2
  displayName: 'Publish Test Results'
  condition: always()
  inputs:
    testResultsFormat: 'NUnit'
    testResultsFiles: '**/Test-Results.xml'

- task: PublishCodeCoverageResults@1
  displayName: 'Publish Code Coverage'
  inputs:
    codeCoverageTool: 'JaCoCo'
    summaryFileLocation: '$(System.DefaultWorkingDirectory)/coverage.xml'
```

---

## GitLab CI

```yaml
stages:
  - test

test:
  stage: test
  image: mcr.microsoft.com/powershell:latest
  script:
    - pwsh -Command "Install-Module -Name Pester -Force -MinimumVersion 5.0"
    - pwsh -Command |
        $config = New-PesterConfiguration
        $config.Run.Path = './tests'
        $config.Run.Exit = $true
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'JUnitXml'
        $config.TestResult.OutputPath = 'test-results.xml'
        Invoke-Pester -Configuration $config
  artifacts:
    when: always
    reports:
      junit: test-results.xml
```

---

## Jenkins

```groovy
pipeline {
    agent any
    
    stages {
        stage('Test') {
            steps {
                pwsh '''
                    Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0
                    
                    $config = New-PesterConfiguration
                    $config.Run.Path = './tests'
                    $config.Run.Exit = $true
                    $config.TestResult.Enabled = $true
                    $config.TestResult.OutputFormat = 'JUnitXml'
                    $config.TestResult.OutputPath = 'test-results.xml'
                    
                    Invoke-Pester -Configuration $config
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }
    }
}
```

---

## Reusable Runner Script

Create `Invoke-Tests.ps1` for local and CI use:

```powershell
[CmdletBinding()]
param(
    [string[]]$Tag,
    [string[]]$ExcludeTag = @('Slow'),
    [string]$FullName,
    [switch]$NoCoverage,
    [int]$CoverageTarget = 80
)

Import-Module Pester -MinimumVersion 5.0

$config = New-PesterConfiguration

# Paths
$config.Run.Path = './tests'
$config.CodeCoverage.Path = './src'

# Filtering
if ($Tag) { $config.Filter.Tag = $Tag }
if ($ExcludeTag) { $config.Filter.ExcludeTag = $ExcludeTag }
if ($FullName) { $config.Filter.FullName = $FullName }

# Code Coverage
$config.CodeCoverage.Enabled = -not $NoCoverage
$config.CodeCoverage.OutputPath = 'coverage.xml'
$config.CodeCoverage.OutputFormat = 'JaCoCo'
$config.CodeCoverage.CoveragePercentTarget = $CoverageTarget

# Test Results
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = 'test-results.xml'
$config.TestResult.OutputFormat = 'JUnitXml'

# Output
$config.Output.Verbosity = 'Detailed'
$config.Output.RenderMode = if ($env:CI) { 'Plaintext' } else { 'Auto' }
$config.Run.Exit = [bool]$env:CI
$config.Run.PassThru = $true

# Run
$result = Invoke-Pester -Configuration $config

# Fail on test failures (for local use)
if ($result.FailedCount -gt 0) {
    throw "$($result.FailedCount) test(s) failed."
}

# Return result for further processing
$result
```

Usage:

```powershell
# Run all unit tests
./Invoke-Tests.ps1

# Run specific tests
./Invoke-Tests.ps1 -FullName '*Get-Widget*'

# Run only tagged tests
./Invoke-Tests.ps1 -Tag 'Integration'

# Quick run without coverage
./Invoke-Tests.ps1 -NoCoverage
```
