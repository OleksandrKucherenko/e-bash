# Version Up

This is a helper script that helps to computer future/next release version of the repository.

Major logic of the script - "on each run script propose future version of the product".
- if no tags on project --> propose `0.0.1-alpha`
- do multiple build iterations until you become satisfied with result
- run `bin/version-up.v2.sh --apply` to save result in GIT

## Major Difference to Semantic Git Commits

ref: [git-cz](https://github.com/streamich/git-cz)

**Semantic Git Commits**:
- each commit may change the version of the product
- developer by selecting a proper "keyword" influence on version increase
- Fixed message format

```txt
<type>[(<scope>)]: <emoji> <subject>
[BLANK LINE]
[body]
[BLANK LINE]
[breaking changes]
[BLANK LINE]
[footer]
```

**Version Up**:
- Developer decide which version number is right for release
- Version Tags - is the source of "truth"
- Multiple commits are NOT a reason to increment version multiple times
- It is a helper script and not designed for modification of other files like `package.json` etc. 
- Composed Java compatible version.properties file that can be used in build scripts
- New branch and it commits is the reason for only one increment (but you can apply multiple tags if needed override)

Both approaches has known issues:
1. Multiple Pull Requests may clash for the same version tag
2. ...TBD...

## Features

- [x] Support Monorepo (sub-project releases)
- [x] Propose a next release version tag
- [x] Save proposed version tag to file `version.properties`
- [x] Detect prefixes of version tags from repository state
  - Support prefix strategy: `root`, `sub-folder`, `any`:
    - `root` - prefix is empty and does not metter in which sub-folder you execute the script;
    - `sub-folder` - prefix is the name of the sub-folder `packages/{module}/v{SEMVER}`;
    - `any` - prefix is the name of the sub-folder `{any}{SEMVER}`;
- [x] Support pre-release stages (alpha, beta, rc)
- [x] Support revision/build increment
- [x] Support git revision (count git commits as a INDEX of the build)
- [x] Support stay on the same version tag
- [x] Hardcoded Priority between `alpha`, `beta`, `rc` and release versions.
- [x] Custom pre-release stage (`-rc.1` for supporting SEMVER fully: `2.0.0-rc.1+build.123`)
- [x] Custom build number (`+build.123` for supporting SEMVER fully: `2.0.0-rc.1+build.123`)

## Usage

```bash
# show help
bin/version-up.v2.sh --help
```

```
Usage:
  bin/version-up.v2.sh [-r|--release] [-a|--alpha] [-b|--beta] [-c|--release-candidate]
                       [-m|--major] [-i|--minor] [-p|--patch] [-e|--revision] [-g|--git|--git-revision]
                       [--prefix root|sub-folder|any] [--stay] [--default]  [--apply]
                       [--version] [--dry-run] [--debug] [--help]

group: action
  --apply      Run GIT command(s) to apply version upgrade. 
  --default    Increment last found part of version, keeping the stage. Increment applied up to MINOR part. 
  --stay       Compose version.properties but do not do any increments. 

group: common
  -e, --revision    Increment REVISION version part. 
  -i, --minor       Increment MINOR version part. 
  -m, --major       Increment MAJOR version part. 
  -p, --patch       Increment PATCH version part. 

group: global
  --debug       Enable debug mode. 
  --dry-run     Run in dry-run mode without making actual changes. 
  --version     Show version and exit. 
  -h, --help    Show help and exit. 

group: special
  --prefix                     Provide tag prefix or use on of the strategies: root, sub-folder (default), any_string 
  -g, --git, --git-revision    Use git revision number as a revision part. 

group: stage
  -a, --alpha                Switch stage to alpha. Set: '-alpha' 
  -b, --beta                 Switch stage to beta. Set: '-beta' 
  -c, --release-candidate    Switch stage to release candidate. Set: '-rc' 
  -r, --release              Switch stage to release, no suffix. 

Version: [PREFIX]MAJOR.MINOR.PATCH[-STAGE][+REVISION]

Reference:
  https://semver.org/

Versions priority:
  1.0.0-alpha < 1.0.0-beta < 1.0.0-rc < 1.0.0
```

### Propose a next release version tag

```bash
# propose a next release version tag without applying it
bin/version-up.v2.sh

# force a new version tag composing with automatic increment
# auto-increment MAJOR part, usually associated with breaking changes
bin/version-up.v2.sh --major  # (MAJOR+1).0.0

# force a new version tag composing with automatic increment
# auto-increment MINOR part, usually associated with new features with backward compatibility
bin/version-up.v2.sh --minor  # MAJOR.(MINOR+1).0

# force a new version tag composing with automatic increment
# auto-increment PATCH part, usually associated with bug fixes with backward compatibility
bin/version-up.v2.sh --patch  # MAJOR.MINOR.(PATCH+1)

# pre-release stage, usually associated with alpha, beta, rc
bin/version-up.v2.sh --alpha  # MAJOR.MINOR.PATCH-alpha
bin/version-up.v2.sh --beta   # MAJOR.MINOR.PATCH-beta
bin/version-up.v2.sh --rc     # MAJOR.MINOR.PATCH-rc

# revision/build increment, usually associated with build number increase on CI phase
bin/version-up.v2.sh --revision # MAJOR.MINOR.PATCH+(REVISION+1)

# git revision (count git commits as a INDEX of the build)
bin/version-up.v2.sh --git    # MAJOR.MINOR.PATCH+(NUMBER_OF_GIT_COMMITS)

# force specific version
bin/version-up.v2.sh --major=1 --minor=1 --patch=10 --revision=9 --rc # v1.1.10-rc+9
```

### Re-publish version from specific version tag

```bash
# checkout branch with the same name as version tag
git checkout -b <version-tag> <version-tag> 

# script will detect that branch and tag are on the same commit 
# and will produce fixed version, in other words will be `--stay` applied
bin/version-up.v2.sh
```

