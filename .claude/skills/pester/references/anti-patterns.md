# Pester Anti-Patterns and Pitfalls

## Table of Contents
1. [Code Outside Pester Blocks](#code-outside-pester-blocks)
2. [Discovery vs Run Phase Issues](#discovery-vs-run-phase-issues)
3. [Mock Scope Problems](#mock-scope-problems)
4. [Test Dependencies](#test-dependencies)
5. [Over-Mocking](#over-mocking)
6. [Production Code Issues](#production-code-issues)

---

## Code Outside Pester Blocks

### Problem
Code placed directly in `Describe` or `Context` runs during Discovery phase, not Run phase.

```powershell
# ❌ WRONG - Variable is null during Run phase
$data = Get-ExpensiveData
Describe 'Tests' {
    It 'uses data' {
        $data | Should -Not -BeNull  # FAILS - $data is null!
    }
}
```

### Solution
Use `BeforeAll` for setup code:

```powershell
# ✅ CORRECT
Describe 'Tests' {
    BeforeAll {
        $script:data = Get-ExpensiveData
    }
    It 'uses data' {
        $script:data | Should -Not -BeNull
    }
}
```

---

## Discovery vs Run Phase Issues

### Using foreach Instead of -ForEach

```powershell
# ❌ WRONG - Variables not available during Run phase
foreach ($file in $files) {
    Describe "$file tests" {
        It 'validates' {
            Get-Content $file  # $file is null!
        }
    }
}
```

```powershell
# ✅ CORRECT - Use BeforeDiscovery + -ForEach
BeforeDiscovery {
    $files = Get-ChildItem *.ps1
}

Describe '<_> tests' -ForEach $files {
    BeforeAll { $file = $_ }
    It 'validates' {
        Get-Content $file | Should -Not -BeNullOrEmpty
    }
}
```

### Using BeforeAll Variables in -TestCases

```powershell
# ❌ WRONG - BeforeAll runs during Run, TestCases evaluated during Discovery
Describe 'Tests' {
    BeforeAll {
        $items = @('a', 'b', 'c')
    }
    It 'processes <_>' -ForEach $items { ... }  # $items is null!
}
```

```powershell
# ✅ CORRECT - Use BeforeDiscovery for test data
BeforeDiscovery {
    $items = @('a', 'b', 'c')
}

Describe 'Tests' {
    It 'processes <_>' -ForEach $items { ... }
}
```

---

## Mock Scope Problems

### Mock in Wrong Scope

```powershell
# ❌ WRONG - Mock only exists in first It block
Describe 'Tests' {
    It 'first test' {
        Mock Get-Data { 'mock' }
        Get-Data | Should -Be 'mock'  # PASSES
    }
    It 'second test' {
        Get-Data | Should -Be 'mock'  # FAILS - no mock!
    }
}
```

```powershell
# ✅ CORRECT - Mock in BeforeAll for Describe scope
Describe 'Tests' {
    BeforeAll {
        Mock Get-Data { 'mock' }
    }
    It 'first test' { Get-Data | Should -Be 'mock' }
    It 'second test' { Get-Data | Should -Be 'mock' }
}
```

### Verifying Mocks Across Scopes

```powershell
# ❌ WRONG - Can't verify calls from BeforeAll in It
Describe 'Tests' {
    BeforeAll {
        Mock Get-Foo {}
        Get-Foo  # Called in BeforeAll
    }
    It 'verifies' {
        Should -Invoke Get-Foo -Times 1  # FAILS - different scope!
    }
}
```

```powershell
# ✅ CORRECT - Call and verify in same scope
Describe 'Tests' {
    BeforeAll { Mock Get-Foo {} }
    It 'verifies' {
        Get-Foo
        Should -Invoke Get-Foo -Times 1
    }
}
```

---

## Test Dependencies

### Tests Relying on Each Other

```powershell
# ❌ WRONG - Test2 depends on Test1's side effect
Describe 'Tests' {
    It 'Test1' {
        $script:value = 'set-by-test1'
    }
    It 'Test2' {
        $script:value | Should -Be 'set-by-test1'  # Fragile!
    }
}
```

```powershell
# ✅ CORRECT - Each test is independent
Describe 'Tests' {
    BeforeEach {
        $script:value = 'default'
    }
    It 'Test1' { $script:value | Should -Be 'default' }
    It 'Test2' { $script:value | Should -Be 'default' }
}
```

### Shared Mutable State

```powershell
# ❌ WRONG - Global variable pollution
$global:counter = 0
Describe 'Tests' {
    It 'increments' { $global:counter++ }
}
```

```powershell
# ✅ CORRECT - Use script scope with cleanup
Describe 'Tests' {
    BeforeEach { $script:counter = 0 }
    It 'increments' { $script:counter++ }
}
```

---

## Over-Mocking

### Testing Implementation Instead of Behavior

```powershell
# ❌ BAD - Fragile, couples test to implementation
It 'processes items' {
    Process-Items -Items @('a', 'b')
    Should -Invoke Internal-Helper -Times 3
    Should -Invoke Format-Output -Times 1
    Should -Invoke Write-Cache -Times 2
}
```

```powershell
# ✅ GOOD - Test observable behavior
It 'processes items' {
    $result = Process-Items -Items @('a', 'b')
    $result.Count | Should -Be 2
    $result[0].Status | Should -Be 'Processed'
}
```

### Mocking the Function Under Test

```powershell
# ❌ WRONG - You're testing the mock, not the function!
Describe 'Get-User' {
    It 'returns user' {
        Mock Get-User { @{ Name = 'Test' } }
        $result = Get-User -Id 1
        $result.Name | Should -Be 'Test'  # Tests nothing!
    }
}
```

```powershell
# ✅ CORRECT - Mock dependencies, not the function under test
Describe 'Get-User' {
    BeforeAll {
        Mock Invoke-RestMethod { @{ Name = 'Test' } }
    }
    It 'returns user from API' {
        $result = Get-User -Id 1
        $result.Name | Should -Be 'Test'
    }
}
```

### Complex Mock Logic

```powershell
# ❌ BAD - Hard to understand and maintain
Mock Get-Data {
    if ($Filter -eq 'A') { return @{x=1} }
    elseif ($Filter -eq 'B') { return @{x=2} }
    elseif ($Filter -match 'C.*') { return @{x=3} }
    else { return $null }
}
```

```powershell
# ✅ BETTER - Separate, focused mocks
Mock Get-Data { @{x=1} } -ParameterFilter { $Filter -eq 'A' }
Mock Get-Data { @{x=2} } -ParameterFilter { $Filter -eq 'B' }
Mock Get-Data { $null }  # Default fallback
```

---

## Production Code Issues

### Hard-Coded Paths

```powershell
# ❌ BAD - Can't test without real file
function Get-Config {
    Get-Content 'C:\App\config.json' | ConvertFrom-Json
}
```

```powershell
# ✅ GOOD - Parameterized path allows TestDrive usage
function Get-Config {
    param([string]$Path = 'C:\App\config.json')
    Get-Content $Path | ConvertFrom-Json
}

# Test with:
Get-Config -Path 'TestDrive:\config.json'
```

### Logic Hidden in Write-Host

```powershell
# ❌ BAD - Hard to test, logic buried in output
function Process-Data {
    $result = Calculate-Something
    Write-Host "Result: $($result.Value)"  # Not testable via pipeline
}
```

```powershell
# ✅ GOOD - Return data, display separately
function Process-Data {
    $result = Calculate-Something
    return $result
}

# Caller decides how to display:
$result = Process-Data
Write-Host "Result: $($result.Value)"
```

### Relying on Current Directory

```powershell
# ❌ BAD - Depends on where script is run from
function Get-LocalFiles {
    Get-ChildItem *.txt  # Uses current directory
}
```

```powershell
# ✅ GOOD - Explicit path parameter
function Get-LocalFiles {
    param([string]$Path = '.')
    Get-ChildItem -Path $Path -Filter *.txt
}
```

---

## Empty TestCases Gotcha

```powershell
# ❌ PROBLEM - Runs once with null if $cases is empty
$cases = @()  # Empty array
It 'processes <Value>' -ForEach $cases {
    $Value | Should -Not -BeNull  # Runs once, $Value is null!
}
```

```powershell
# ✅ SOLUTION - Skip if no data
Describe 'Tests' -Skip:(-not $cases) {
    It 'processes <Value>' -ForEach $cases {
        $Value | Should -Not -BeNull
    }
}
```

---

## Best Practices Summary

1. **All code in lifecycle blocks** - `BeforeAll`, `BeforeEach`, `It`, `AfterEach`, `AfterAll`
2. **Use `BeforeDiscovery`** for dynamic test generation data
3. **Mock at appropriate scope** - usually `BeforeAll` or `BeforeEach`
4. **Each test is independent** - no reliance on execution order
5. **Test behavior, not implementation** - avoid over-specifying mock calls
6. **Design for testability** - parameterized paths, injectable dependencies
7. **Use TestDrive/TestRegistry** - avoid real filesystem/registry pollution
8. **Tag slow tests** - enable fast TDD loops with `-ExcludeTagFilter 'Slow'`
