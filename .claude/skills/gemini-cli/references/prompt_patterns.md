# Gemini CLI Prompt Patterns

Effective prompts for maximizing Gemini's 1M token context window.

## Codebase Analysis Prompts

### Architecture Review
```
Analyze this codebase's architecture:
1. Identify architectural patterns (MVC, Clean Architecture, etc.)
2. Map component dependencies and coupling
3. Evaluate separation of concerns
4. Identify architectural anti-patterns
5. Recommend improvements with priority ranking
```

### Security Audit
```
Perform a security audit of this codebase:
1. Identify hardcoded secrets or credentials
2. Find SQL injection vulnerabilities
3. Check for XSS attack vectors
4. Evaluate authentication/authorization implementation
5. Review input validation and sanitization
6. Check dependency vulnerabilities
7. Assess data handling and encryption
```

### Performance Analysis
```
Analyze performance characteristics:
1. Identify N+1 query patterns
2. Find memory leak risks
3. Evaluate caching strategies
4. Check for synchronous blocking operations
5. Assess database query efficiency
6. Review resource cleanup patterns
```

### Migration Assessment
```
Assess migration from [source] to [target]:
1. Identify breaking changes
2. Map deprecated APIs to replacements
3. Estimate effort per component
4. Propose migration sequence
5. Identify risk areas requiring extra testing
6. Recommend rollback strategy
```

## Deep Analysis Prompts

### Architecture Decision
```
I need to decide between [Option A] and [Option B] for [purpose].

Context:
- Requirements: [list]
- Constraints: [list]
- Team expertise: [description]
- Timeline: [timeframe]

Analyze both options considering:
1. Technical fit for requirements
2. Long-term maintainability
3. Team learning curve
4. Scalability implications
5. Cost considerations
6. Risk assessment

Provide a recommendation with supporting rationale.
```

### Refactoring Strategy
```
Plan refactoring for [component/module]:

Current state:
- [describe current issues]

Goals:
- [describe desired outcomes]

Constraints:
- Cannot break existing API contracts
- Must maintain backwards compatibility
- Limited to [X] sprint capacity

Provide:
1. Refactoring approach
2. Step-by-step execution plan
3. Testing strategy
4. Rollback plan
5. Success metrics
```

## Second Opinion Prompts

### Code Review Validation
```
Another reviewer suggested these changes:
[paste suggestions]

For codebase context, review the suggestions:
1. Which suggestions improve code quality?
2. Which suggestions might introduce issues?
3. What alternative approaches exist?
4. Are there suggestions missing?
```

### Design Review
```
This system design was proposed:
[paste design]

Critically evaluate:
1. Does it meet stated requirements?
2. What failure modes exist?
3. How will it scale?
4. What's the operational complexity?
5. What alternatives should be considered?
```

## Context Maximization Tips

### Effective Context Loading
```bash
# Include only relevant directories
gemini --include-directories ./src,./tests "analyze"

# Exclude noise
# Use .geminiignore file to exclude build artifacts, node_modules, etc.
```

### Structured Multi-File Analysis
```
Analyze these related files together:

File: src/auth/service.ts
Purpose: Authentication service

File: src/auth/middleware.ts  
Purpose: Auth middleware

File: src/auth/types.ts
Purpose: Type definitions

Focus on:
1. Consistency across files
2. Type safety
3. Error handling patterns
```

### Progressive Disclosure
For very large codebases, use interactive mode with progressive exploration:

```bash
gemini -i "Start with high-level architecture overview"
# Then drill down
> "Now focus on the authentication module"
> "Show me security concerns in auth"
```
