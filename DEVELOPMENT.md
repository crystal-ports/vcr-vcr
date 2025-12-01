# Development

This file details as many important parts of the process that you may need to know about working on VCR.cr, should any of us get hit by a bus.

## Releasing

  0. Make a branch from the base branch
  0. Change the version in `shard.yml` and `src/vcr/version.cr`, based on SEMVER
  0. Denote changes since last release in changelog file (see changelog notation below)
  0. Commit the changes with the body "Bumping to version X.Y.Z"
  0. Push the branch
  0. Make a pull request
  0. Get it merged
  0. Pull down the new master
  0. Create a git tag: `git tag vX.Y.Z && git push origin vX.Y.Z`
  0. Grab a drink

Ancillary: At your leisure make a Release on GitHub with the changelog differences. It's very helpful for many people.

## Changelog

We use a very rudimentary changelog system focusing on three primary things people care about: Breaking Changes, New Features, and Bug fixes. Anything outside of that is worthless for people looking at the changelog in my experience. Here's a snippet for a new changelog entry:

``` markdown
## 5.1.0 (Feb 5, 2020)
[Full Changelog](https://github.com/crystal-ports/vcr-vcr/v5.0.0...v5.1.0)
  - [new] Some new feature (#774)
  - [patch] Some bug fix (#782)
  - [breaking] Some breaking change (#758)
```

Notice a few things here:

  0. These log lines are basically from git log, thankfully including the PR.
  0. The header is the version and the rough date.
  0. The header has a link to the diff. Honestly, it should just be the release, but chicken-egg.
  0. We have 3 tags: [new], [patch], [breaking]. Use those to help people focus on what they should care about. Sometimes the PR will already have that for you.
