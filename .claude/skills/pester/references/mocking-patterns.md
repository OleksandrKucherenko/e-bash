# Advanced Pester Mocking Patterns

## Table of Contents
1. [Mock Scoping](#mock-scoping)
2. [Conditional Mocks](#conditional-mocks)
3. [Native Commands](#native-commands)
4. [.NET Type Workarounds](#net-type-workarounds)
5. [Module Internals](#module-internals)
6. [Verifying Calls](#verifying-calls)
7. [Common Scenarios](#common-scenarios)

---

## Mock Scoping

Mocks are scoped to their containing block. They're automatically removed when the block exits.

```powershell
Describe 'Outer' {
    BeforeAll {
        Mock Get-Date { [DateTime]'2024-01-01' }  # Scope: entire Describe
    }

    It 'uses outer mock' {
        Get-Date | Should -Be ([DateTime]'2024-01-01')
    }

    Context 'Inner' {
        BeforeAll {
            Mock Get-Date { [DateTime]'2024-12-31' }  # Overrides for this Context
        }

        It 'uses inner mock' {
            Get-Date | Should -Be ([DateTime]'2024-12-31')
        }
    }

    It 'outer mock restored' {
        Get-Date | Should -Be ([DateTime]'2024-01-01')
    }
}
```

---

## Conditional Mocks

### Parameter Filters

Mocks with `-ParameterFilter` are evaluated in reverse order. First match wins.

```powershell
BeforeAll {
    # Default (no filter) - evaluated last
    Mock Invoke-RestMethod { @{ Error = 'Unknown endpoint' } }
    
    # Specific endpoints - evaluated first
    Mock Invoke-RestMethod { @{ Users = @() } } -ParameterFilter {
        $Uri -like '*/users*'
    }
    Mock Invoke-RestMethod { @{ Posts = @() } } -ParameterFilter {
        $Uri -like '*/posts*'
    }
}
```

### Returning Different Values per Call

Use a script-scoped counter:

```powershell
BeforeAll {
    $script:callCount = 0
    Mock Get-Data {
        $script:callCount++
        switch ($script:callCount) {
            1 { 'first-call' }
            2 { 'second-call' }
            default { 'subsequent' }
        }
    }
}
```

### Throwing Errors

```powershell
Mock Get-Service { throw 'Service not found' } -ParameterFilter {
    $Name -eq 'NonExistent'
}

It 'handles missing service' {
    { Get-ServiceInfo -Name 'NonExistent' } | Should -Throw '*not found*'
}
```

---

## Native Commands

### Mocking bash/git/curl

Native commands receive arguments as `$args` array:

```powershell
Describe 'Git Wrapper' {
    BeforeAll {
        Mock git {
            # Return based on command
            switch ($args[0]) {
                'status' { 'On branch main' }
                'log'    { 'commit abc123' }
                'push'   { 'Everything up-to-date' }
                default  { '' }
            }
        }
    }

    It 'calls git push with correct args' {
        Push-ToRemote -Branch 'main' -Remote 'origin'
        
        Should -Invoke git -ParameterFilter {
            $args[0] -eq 'push' -and
            $args[1] -eq 'origin' -and
            $args[2] -eq 'main'
        }
    }
}
```

### Simulating Exit Codes

```powershell
Mock curl {
    $global:LASTEXITCODE = 0
    '{"status":"ok"}'
}

Mock curl {
    $global:LASTEXITCODE = 1
    ''
} -ParameterFilter { $args -contains '--fail' -and $args -contains 'http://bad.url' }
```

### Bash Script Mocking

```powershell
Describe 'Bash Integration' {
    BeforeAll {
        Mock bash {
            # Simulate script output
            '{"result":"success","count":42}'
        }
    }

    It 'parses bash script JSON output' {
        $result = Invoke-BashScript -Script './process.sh'
        $result.count | Should -Be 42
    }

    It 'passes arguments correctly' {
        Invoke-BashScript -Script './deploy.sh' -Args @('--env', 'prod')
        
        Should -Invoke bash -ParameterFilter {
            "$args" -match './deploy.sh' -and
            "$args" -match '--env' -and
            "$args" -match 'prod'
        }
    }
}
```

---

## .NET Type Workarounds

Pester cannot mock static .NET methods directly. Use wrapper functions:

### The Wrapper Pattern

```powershell
# Production code - create thin wrappers
function Test-FileExistsWrapper {
    param([string]$Path)
    [System.IO.File]::Exists($Path)
}

function Get-CurrentTimeWrapper {
    [DateTime]::UtcNow
}

# Your function uses wrappers instead of direct .NET calls
function Get-FileAge {
    param([string]$Path)
    if (Test-FileExistsWrapper -Path $Path) {
        $now = Get-CurrentTimeWrapper
        # ... logic
    }
}

# Tests can mock the wrappers
Describe 'Get-FileAge' {
    BeforeAll {
        Mock Test-FileExistsWrapper { $true }
        Mock Get-CurrentTimeWrapper { [DateTime]'2024-06-15 12:00:00' }
    }

    It 'calculates age correctly' {
        # Test without hitting real filesystem
    }
}
```

### Using New-MockObject

Create mock objects that satisfy type requirements:

```powershell
BeforeAll {
    $mockService = New-MockObject -Type 'System.ServiceProcess.ServiceController'
    $mockService | Add-Member -MemberType NoteProperty -Name Status -Value 'Running'
    $mockService | Add-Member -MemberType NoteProperty -Name Name -Value 'TestService'
    
    Mock Get-Service { $mockService }
}
```

---

## Module Internals

### Mocking Inside Modules

Use `-ModuleName` to inject mocks into module scope:

```powershell
BeforeAll {
    Import-Module ./MyModule.psm1
    
    # Mock inside the module's scope
    Mock -ModuleName MyModule Get-InternalConfig {
        @{ ConnectionString = 'test-db' }
    }
}

It 'uses mocked internal config' {
    # Public function calls internal Get-InternalConfig
    $result = Get-ModuleData
    $result.Source | Should -Be 'test-db'
}
```

### Testing Private Functions with InModuleScope

```powershell
Describe 'Private Function Tests' {
    BeforeAll {
        Import-Module ./MyModule.psm1
    }

    It 'tests private helper' {
        InModuleScope MyModule {
            # Inside module scope - can see private functions
            $result = ConvertTo-InternalFormat -Input 'test'
            $result | Should -Be 'TEST_INTERNAL'
        }
    }

    It 'mocks within module scope' {
        InModuleScope MyModule {
            Mock Write-AuditLog {}
            
            Invoke-PrivateOperation -Data 'test'
            
            Should -Invoke Write-AuditLog -Times 1
        }
    }
}
```

**Caution**: Prefer testing through public APIs when possible. InModuleScope couples tests to implementation details.

---

## Verifying Calls

### Should -Invoke (Pester 5+)

```powershell
# Verify call count
Should -Invoke Send-Email -Times 1 -Exactly
Should -Invoke Send-Email -Times 0          # Never called
Should -Invoke Send-Email -Exactly -Times 3 # Exactly 3 times

# Verify parameters
Should -Invoke Send-Email -ParameterFilter {
    $To -eq 'admin@example.com' -and
    $Subject -like '*Alert*'
}

# Verify scope
Should -Invoke Get-Data -Times 2 -Scope Describe  # Total in Describe
Should -Invoke Get-Data -Times 1 -Scope It        # Only in this It block

# Negative assertion
Should -Not -Invoke Send-Email
```

### Verifiable Mocks

Mark mocks that must be called:

```powershell
BeforeAll {
    Mock Initialize-Connection {} -Verifiable
    Mock Close-Connection {} -Verifiable
}

It 'calls required lifecycle methods' {
    Process-Data -Data 'test'
    
    Should -InvokeVerifiable  # Fails if any -Verifiable mock wasn't called
}
```

---

## Common Scenarios

### API/REST Calls

```powershell
Describe 'API Client' {
    BeforeAll {
        Mock Invoke-RestMethod {
            @{
                id = 1
                name = 'Test User'
                email = 'test@example.com'
            }
        } -ParameterFilter { $Uri -like '*/users/*' -and $Method -eq 'GET' }

        Mock Invoke-RestMethod {
            @{ success = $true; id = 999 }
        } -ParameterFilter { $Method -eq 'POST' }
    }

    It 'gets user' {
        $user = Get-ApiUser -Id 1
        $user.name | Should -Be 'Test User'
    }

    It 'creates user with correct payload' {
        New-ApiUser -Name 'New' -Email 'new@test.com'
        
        Should -Invoke Invoke-RestMethod -ParameterFilter {
            $Method -eq 'POST' -and
            ($Body | ConvertFrom-Json).name -eq 'New'
        }
    }
}
```

### Database Operations

```powershell
Describe 'Database Repository' {
    BeforeAll {
        Mock Invoke-SqlCmd {
            @(
                @{ Id = 1; Name = 'Widget A' }
                @{ Id = 2; Name = 'Widget B' }
            )
        }
    }

    It 'queries with correct SQL' {
        Get-Widgets -Category 'Active'
        
        Should -Invoke Invoke-SqlCmd -ParameterFilter {
            $Query -like '*WHERE Category*Active*'
        }
    }
}
```

### File Operations with TestDrive

```powershell
Describe 'Config Manager' {
    BeforeAll {
        $configPath = 'TestDrive:\config.json'
        @{ setting = 'value' } | ConvertTo-Json | Set-Content $configPath
    }

    It 'reads config' {
        $cfg = Get-Config -Path $configPath
        $cfg.setting | Should -Be 'value'
    }

    It 'updates config' {
        Set-ConfigValue -Path $configPath -Key 'setting' -Value 'new'
        
        $updated = Get-Content $configPath | ConvertFrom-Json
        $updated.setting | Should -Be 'new'
    }
}
```

### Timing/Date Operations

```powershell
Describe 'Scheduler' {
    BeforeAll {
        $fixedDate = [DateTime]'2024-06-15 14:30:00'
        Mock Get-Date { $fixedDate }
    }

    It 'schedules for tomorrow' {
        $scheduled = New-ScheduledTask -In '1 day'
        $scheduled.RunAt | Should -Be ([DateTime]'2024-06-16 14:30:00')
    }
}
```

### Environment Variables

```powershell
Describe 'Environment Config' {
    BeforeEach {
        $script:origEnv = $env:APP_ENV
        $env:APP_ENV = 'testing'
    }

    AfterEach {
        $env:APP_ENV = $script:origEnv
    }

    It 'uses test environment' {
        Get-EnvironmentName | Should -Be 'testing'
    }
}
```
