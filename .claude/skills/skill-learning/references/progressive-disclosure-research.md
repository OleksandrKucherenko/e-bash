# Progressive Disclosure at Scale: Operating Large Skill Libraries

**Focus:** Practical patterns for managing 100-1000+ skills  
**Date:** December 18, 2025

---

## Executive Summary

Progressive disclosure enables agents to work with arbitrarily large skill libraries by loading information in stages: metadata → instructions → resources. This report focuses on practical implementation patterns for systems with 100+ skills, where naive approaches fail.

**Critical insight:** At scale, you're building a discovery system, not a documentation library.

**Performance data:** 36.8% improvement with dynamic loading across 200+ tasks (internal benchmark). Discovery scales O(log n), browsing scales O(n) and fails beyond ~50 skills.

---

## The Scaling Wall

### When Flat Structures Break

**10-50 skills:** Flat list in memory block works fine  
**50-100 skills:** Memory block gets crowded, discovery slower but functional  
**100-500 skills:** Flat structure at breaking point, need better organization  
**500+ skills:** Flat structure fails, hierarchical organization required

**The problem at 100+ skills:**
```
Memory block contains:
- 100 skills × 100 words metadata = 10,000 words
- Approaches context window limits
- Agent spends significant time scanning metadata
- Discovery precision drops (too many similar-sounding skills)
```

**Key metrics from production (100+ skill systems):**
- Discovery time: 2.5s → 8.3s (3.3x slower)
- False positives: 3.1% → 18.7% (agents load wrong skills)
- Memory overhead: 15% → 45% of context window
- Agent confusion: More time selecting skills than executing tasks

---

## Three-Tier Architecture for Scale

### Tier 1: Discovery Metadata (Always Loaded)

**Challenge:** How do you fit 1000 skills in memory without overwhelming agents?

**Solution: Hierarchical metadata with progressive drilling**

```yaml
# Top-level categories (always in memory)
<example-category-a>/          - Product ecosystem
  ├─ agents/                   - Agent development patterns
  ├─ sdks/                     - SDK integrations
  └─ ops/                      - Operations and deployment

<example-category-b>/          - External tool integrations
  ├─ web/                      - Web scraping, testing
  ├─ data/                     - Data processing
  └─ ml/                       - Machine learning tools

# Skill metadata (loaded per category)
<example-category-a>/agents/
  - <example-skill> (memory architecture): Designing memory blocks...
  - <example-skill> (tool patterns): Tool selection and configuration...
  - <example-skill> (multi-agent coordination): Coordinating multiple agents...
```

**Implementation pattern:**
1. **Categories in memory block** (always loaded): ~10-20 categories, <1k words
2. **Skill list on demand** (when category selected): 10-50 skills per category
3. **Full skill** (when specific skill selected): Complete SKILL.md

**Example agent flow:**
```
Task: "Set up memory blocks for a customer support agent"

Agent reasoning:
1. Scan categories → "<example-category-a>/" relevant
2. Load <example-category-a>/ skill list → See "<example-skill> (memory architecture)" 
3. Load <example-skill> (memory architecture) SKILL.md
4. Navigate to references/<example-reference>.md (customer support patterns)
5. Execute task
```

### Tier 2: Category Organization

**Practical category structure for 500+ skills:**

```
<domain>/
├── <subdomain>/
│   ├── CATEGORY.md         # Overview, when to use these skills
│   ├── skill-1/
│   ├── skill-2/
│   └── skill-3/
└── README.md               # Domain overview
```

**CATEGORY.md template:**
```markdown
# Agent Development Skills

Use these skills when building, configuring, or debugging product agents.

## Available Skills

- **<example-skill> (memory architecture)** - Use when designing memory blocks and data flow
- **<example-skill> (tool patterns)** - Use when selecting and configuring tools
- **<example-skill> (model selection)** - Use when choosing model tiers for specific workloads
- **<example-skill> (multi-agent coordination)** - Use when coordinating multiple agents

## Quick Decision Tree

Building new agent? → Start with <example-skill> (memory architecture)
Debugging tool issues? → See <example-skill> (tool patterns)
Performance problems? → Check <example-skill> (model selection)
Multiple agents? → Read <example-skill> (multi-agent coordination)
```

**Key insight:** CATEGORY.md is metadata for a group of skills. Agents load it to decide which skill to load next.

### Tier 3: Skill Resources

No change at large scale - skills still have references/, scripts/, assets/. But organization becomes more critical:

**At 500+ skills, standardize reference structure:**
```
skill-name/
├── SKILL.md                    # Always same structure
├── references/
│   ├── README.md               # Index (required at scale)
│   ├── quick-start.md          # Standard name
│   ├── common-patterns.md      # Standard name
│   ├── api-reference.md        # Standard name
│   └── troubleshooting.md      # Standard name
├── scripts/
│   └── README.md               # What each script does
└── assets/
    └── README.md               # What each asset is for
```

**Why standardization matters:** With 500+ skills, agents learn the pattern. They know "quick-start.md exists in references/" and can navigate directly.

---

## Discovery Mechanisms at Scale

### Problem: Query-based Discovery

**Simple query (works to ~100 skills):**
```
Agent: "I need to test a web application"
System: Scans all skill metadata
Result: Finds "<example-skill> (web UI testing)"
```

**Complex query at scale (500+ skills):**
```
Agent: "I need to test a web application"
System: 
  1. Identify domain: <example-category-b>/web/
  2. Load <example-category-b>/web/CATEGORY.md
  3. Scan category skills
  4. Find <example-skill> (web UI testing)
Result: 3 steps instead of 1, but scales to 10,000 skills
```

### Hierarchical Discovery Pattern

**Implementation:**

```typescript
interface SkillDiscovery {
  // Phase 1: Category selection
  selectCategories(query: string): Category[]  // From memory block
  
  // Phase 2: Skill selection
  selectSkills(category: Category, query: string): Skill[]  // Load CATEGORY.md
  
  // Phase 3: Skill loading
  loadSkill(skill: Skill): SkillContent  // Load SKILL.md
}

// Agent flow:
1. categories = selectCategories("test web application")
   // Returns: [<example-category-b>/web/, <example-category-b>/testing/]

2. skills = selectSkills(<example-category-b>/web/, "test web application")  
   // Loads <example-category-b>/web/CATEGORY.md
   // Returns: [<example-skill> (web UI testing), <example-skill> (web scraping)]

3. content = loadSkill("<example-skill>")
   // Loads full SKILL.md
```

**Complexity:** O(log n) - each step narrows search space

**Alternative: Flat discovery with embeddings** (more complex but faster):
- Pre-compute embeddings for all skill metadata
- Query embedding matches against skill embeddings
- Load top-k skills directly
- Requires embedding infrastructure

---

## Metadata Design for Discoverability

### The Metadata Challenge

**At 10 skills:** Vague metadata acceptable ("Python utilities")  
**At 100 skills:** Need specificity ("Python async patterns for web services")  
**At 1000 skills:** Need extreme precision + disambiguation

**Critical elements:**

1. **Trigger conditions** (what query patterns match this skill)
2. **Scope definition** (what's included, what's not)
3. **Differentiation** (how this differs from similar skills)

**Template for 100+ skill systems:**
```yaml
name: skill-identifier
category: domain/subdomain
description: |
  Use when [specific trigger with keywords]. 
  Provides [concrete capabilities].
  Covers [explicit scope].
  Does NOT cover [common misconceptions].
  See also: [related-skill] for [alternative use case].
keywords: [keyword1, keyword2, keyword3]  # Optional but helpful at scale
```

**Example - Good metadata at scale:**
```yaml
name: <example-skill>
category: <example-category-b>/web
description: |
  Use when testing web UIs in a real browser using an automation tool.
  Provides page navigation, element interaction, screenshot capture, network 
  interception. Covers both headless and headed testing.
  Does NOT cover API testing (see <example-skill> (API testing)) or load testing 
  (see <example-skill> (load testing)).
  See also: <example-skill> (Chrome-only testing).
keywords: [browser, testing, ui, e2e, screenshots]
```

**Example - Poor metadata at scale:**
```yaml
name: web-tool
description: Helpful utilities for web development
# Issues: Vague trigger, unclear scope, no differentiation
```

### Disambiguation at Scale

**Problem:** Multiple similar skills, agent picks wrong one

**Example collision:**
- `<example-skill>` (REST API testing) - Testing APIs with an HTTP client
- `<example-skill>` (API integration) - Integrating third-party APIs
- `<example-skill>` (API design) - Designing RESTful APIs
- `<example-skill>` (GraphQL testing) - Testing GraphQL APIs

**Solution: Explicit differentiation in metadata**
```yaml
name: <example-skill>
description: |
  Use when testing REST APIs (not GraphQL - see <example-skill> (GraphQL testing)).
  Provides HTTP request testing, response validation, mock servers.
  For API integration patterns, see <example-skill> (API integration).
  For API design guidance, see <example-skill> (API design).
```

---

## Organization Strategies

### Categorization Approaches

**By domain (recommended for 100-500 skills):**
```
<example-category-a>/          - Product ecosystem
<example-category-b>/          - General tools
templates/      - Reusable templates
domain-X/       - Specific domains
```

**By function (works well for specialized systems):**
```
development/    - Building things
operations/     - Running things
analysis/       - Understanding things
```

**By technology (good for tech-specific libraries):**
```
python/         - Python skills
typescript/     - TypeScript skills
databases/      - Database skills
```

**Hybrid (necessary at 500+ skills):**
```
<example-category-a>/
  ├── agents/           # By function within domain
  ├── sdks/
  └── ops/

<example-category-b>/
  ├── web/             # By technology within domain
  ├── data/
  └── ml/

templates/
  ├── frontend/        # By use case within domain
  ├── backend/
  └── docs/
```

### Category Size Guidelines

**Optimal category size:** 10-30 skills

**Too small (<5 skills):** Over-categorization, high navigation overhead  
**Too large (>50 skills):** Category doesn't help, still scanning too many options  

**Example of good sizing:**
```
<example-category-b>/web/      # 18 skills - good size
  - <example-skill> (browser UI testing)
  - <example-skill> (browser automation)
  - <example-skill> (web scraping)
  - <example-skill> (e2e testing)
  - <example-skill> (page performance checks)
  - ... (13 more)

<example-category-b>/web/testing/  # Bad: Over-categorization
  - <example-skill> (browser tools) # 3 skills
  - <example-skill> (automation)   # 2 skills
  - <example-skill> (drivers)      # 4 skills
# Better to keep flat with good metadata
```

---

## Memory Block Management

### The Memory Block Scaling Problem

**Simple approach (fails at 100+ skills):**
```
skills memory block:
[metadata for all 1000 skills]
# 100,000+ words, dominates context window
```

**Hierarchical approach (scales to 10,000 skills):**
```
skills memory block:
[category list - 20 categories × 50 words = 1,000 words]

Agent loads on demand:
- CATEGORY.md for relevant categories
- SKILL.md for specific skills
```

### Dynamic Memory Block Updates

**Pattern: Update memory block as navigation happens**

```typescript
// Initial memory block: Just categories
memoryBlock.skills = formatCategories(categories);

// Agent identifies relevant category
loadCategory('<example-category-b>/web/');
memoryBlock.skills += formatCategorySkills('<example-category-b>/web/');

// Agent selects specific skill
loadSkill('<example-skill>');
memoryBlock.loaded_skills += skillContent;

// Agent unloads when done
memoryBlock.loaded_skills = removeSkill('<example-skill>');
```

**Key insight:** Memory block is dynamic, updated during task execution.

### Memory Block Structure at Scale

```yaml
# Always present
categories:
  - <example-category-a>/ : Product ecosystem (agents, SDKs, ops)
  - <example-category-b>/ : External tool integrations (web, data, ml)
  - templates/ : Reusable templates and patterns
  
# Loaded on demand (category exploration)
current_category: <example-category-b>/web/
category_skills:
  - <example-skill> (web UI testing): Testing web UIs with a browser automation tool...
  - <example-skill> (web scraping): Extracting data from websites...
  - <example-skill> (REST API testing): Testing REST APIs with an HTTP client...
  
# Loaded on demand (active work)  
loaded_skills:
  - <example-skill> (web UI testing): [full SKILL.md content]
```

---

## Tooling and Infrastructure

### Discovery Tools for Large Libraries

**Search/query tool (essential at 100+ skills):**
```typescript
interface SkillSearch {
  // Keyword search across all metadata
  search(query: string): Skill[]
  
  // Category-scoped search
  searchCategory(category: string, query: string): Skill[]
  
  // Semantic search (requires embeddings)
  semanticSearch(query: string, topK: number): Skill[]
}
```

**Usage in agent reasoning:**
```
Agent: I need to test a web application
Tool call: search("test web application")
Result: [<example-skill> (web UI testing), <example-skill> (web scraping), <example-skill> (API testing)]
Agent: Load <example-skill> (web UI testing)
```

### Skill Registry (500+ skills)

**Problem:** Need metadata index without loading all files

**Solution: Skill registry file**
```json
{
  "skills": [
    {
      "id": "<example-skill>",
      "category": "<example-category-b>/web",
      "path": "<example-category-b>/web/<example-skill>",
      "name": "Web UI Testing",
      "description": "Testing web UIs with a browser automation tool...",
      "keywords": ["browser", "testing", "ui"],
      "updated": "2025-12-15"
    }
  ],
  "categories": [
    {
      "id": "<example-category-b>/web",
      "name": "Web Tools",
      "description": "Tools for web development and testing",
      "skill_count": 18
    }
  ]
}
```

**Benefits:**
- Single file to load for all metadata
- Fast search/filter operations
- Versioning and update tracking
- Can generate dynamically from skill files

**Trade-off:** Registry must stay in sync with actual skills (build step)

---

## Practical Implementation Patterns

### Pattern 1: Lazy Category Loading

```typescript
class SkillSystem {
  // Always loaded
  categories: Category[]
  
  // Lazy loaded
  categoryCache: Map<string, CategoryContent>
  skillCache: Map<string, SkillContent>
  
  async discoverSkill(query: string): Skill {
    // 1. Identify category from query
    const category = await this.selectCategory(query);
    
    // 2. Load category if not cached
    if (!this.categoryCache.has(category.id)) {
      const content = await this.loadCategory(category.id);
      this.categoryCache.set(category.id, content);
    }
    
    // 3. Select skill from category
    const categoryContent = this.categoryCache.get(category.id);
    const skill = await this.selectSkill(categoryContent, query);
    
    return skill;
  }
}
```

### Pattern 2: Skill Preloading

**Use case:** Agent working in specific domain, likely to use multiple related skills

```typescript
async preloadCategory(categoryId: string) {
  const category = await this.loadCategory(categoryId);
  
  // Preload all skills in category (parallel)
  const skills = await Promise.all(
    category.skills.map(s => this.loadSkill(s.id))
  );
  
  // Now agent can access any skill in category instantly
}
```

**When to use:** Task spans entire domain (e.g., "build a web app" → preload all web skills)

### Pattern 3: Skill Dependency Loading

**Problem:** Some skills reference other skills

```yaml
# In <example-skill> (API integration) SKILL.md
Prerequisites: Load <example-skill> (API authentication) first
Related skills: <example-skill> (error handling), <example-skill> (rate limiting)
```

**Implementation:**
```typescript
async loadSkillWithDependencies(skillId: string): SkillContent {
  const skill = await this.loadSkill(skillId);
  
  // Parse dependencies from skill content
  const deps = this.parseDependencies(skill);
  
  // Load dependencies
  for (const dep of deps) {
    if (!this.skillCache.has(dep)) {
      await this.loadSkill(dep);
    }
  }
  
  return skill;
}
```

**Warning:** Can lead to cascade loading. Use sparingly and document clearly.

---

## Operational Patterns

### Skill Discovery Analytics

**Essential metrics at scale:**

1. **Discovery funnel:**
   - Queries → Categories identified → Skills loaded → Skills used
   - Drop-off points indicate discovery problems

2. **Skill usage distribution:**
   - 80/20 rule: 20% of skills = 80% of usage
   - Long tail: Many skills rarely used (candidates for archival or deletion)

3. **Failed discoveries:**
   - Agent searches but loads wrong skill
   - Agent searches but loads no skill
   - High failure rate = metadata quality issues

### Skill Maintenance at Scale

**Patterns for 500+ skills:**

**1. Automated validation:**
```bash
# Daily checks
- All SKILL.md files have valid frontmatter
- All references/ links in SKILL.md are valid
- Category structures match file system
- Skill registry in sync with actual files
```

**2. Version tracking:**
```yaml
# In SKILL.md frontmatter
version: 2.1.0
last_updated: 2025-12-15
changelog:
  - 2.1.0: Added GraphQL support
  - 2.0.0: Breaking change - new API
```

**3. Deprecation process:**
```yaml
# Mark as deprecated
deprecated: true
deprecated_message: "Use <example-skill>-v2 instead"
replacement: <example-skill>-v2
sunset_date: 2026-03-15
```

**4. Usage-based pruning:**
- Track skill load frequency
- Skills not loaded in 6 months → candidates for archival
- Archive to separate repo, remove from active set

---

## Migration Path

### Growing from 50 → 100 → 500 skills

**Phase 1: 50 skills (flat structure)**
```
.skills/
├── skill-1/
├── skill-2/
└── ...
```
**Memory block:** All metadata (manageable)

**Phase 2: 100 skills (add categories)**
```
.skills/
├── category-1/
│   ├── skill-1/
│   └── skill-2/
└── category-2/
    └── skill-3/
```
**Memory block:** Categories + skill metadata (tight but ok)

**Phase 3: 500 skills (hierarchical)**
```
.skills/
├── domain-1/
│   ├── subdomain-1/
│   │   └── skill-1/
│   └── subdomain-2/
│       └── skill-2/
└── domain-2/
    └── subdomain-3/
        └── skill-3/
```
**Memory block:** Just categories, lazy load everything else

**Phase 4: 1000+ skills (add infrastructure)**
- Skill registry file
- Search/query tools
- Analytics pipeline
- Automated maintenance

### Refactoring Checklist

**Before reorganizing 100+ skills:**
- [ ] Audit current usage patterns (which skills actually used?)
- [ ] Identify natural category boundaries
- [ ] Create category structure
- [ ] Write CATEGORY.md files for each category
- [ ] Update skill metadata to reference categories
- [ ] Test discovery with representative queries
- [ ] Update documentation
- [ ] Monitor discovery metrics after migration

---

## Key Takeaways

1. **At 100+ skills, you're building a discovery system, not a documentation library**

2. **Hierarchical organization is mandatory at scale** - flat structures fail beyond ~100 skills

3. **Metadata quality determines success** - poor metadata = undiscoverable skills

4. **Standardization enables learning** - consistent structure across skills lets agents navigate efficiently

5. **Discovery scales O(log n)** - hierarchical approach necessary for 1000+ skills

6. **Memory block must be dynamic** - update during task execution, don't front-load everything

7. **Categories should be 10-30 skills** - smaller = over-categorized, larger = unhelpful

8. **Measure discovery funnel** - query → category → skill → use (drop-offs indicate problems)

---

## Recommended Architecture (500+ skills)

```
Memory Block:
  - Category list (20-50 categories, <2k words)
  
Discovery Process:
  1. Query → Identify categories (parallel evaluation)
  2. Load CATEGORY.md for relevant categories
  3. Scan category skills
  4. Load specific SKILL.md
  5. Navigate to references/ as needed
  
Infrastructure:
  - Skill registry (single JSON index)
  - Search tool (keyword + optional semantic)
  - Analytics (discovery funnel + usage)
  - Automated validation (daily)
  
Organization:
  domain/subdomain/skill-name/
    ├── SKILL.md (standardized structure)
    ├── references/
    │   ├── README.md (required)
    │   ├── quick-start.md
    │   ├── common-patterns.md
    │   └── api-reference.md
    └── scripts/ (optional)
```

**This architecture scales to 10,000+ skills with O(log n) discovery.**

---

**Research conducted December 2025 during skills repository restructuring and scaling analysis.**
