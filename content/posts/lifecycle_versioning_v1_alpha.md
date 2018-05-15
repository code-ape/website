+++
title = "Lifecycle Versioning (v01, alpha)"
date = "2018-02-02"
tags = ["Software Development", "Lifecycle Versioning"]

summary = '''
A descriptoin of what Lifecycle Versioning is, its value as a software development practice, and how to implement it. Currently in alpha form of version 1, feedback welcome.
'''

repository = "https://github.com/code-ape/website/blob/master/content/posts/lifecycle_versioning_v1_alpha.md"

version_history = "https://github.com/code-ape/website/commits/gh-pages/posts/lifecycle_versioning_v1_alpha/index.html"
+++

*The following document is versioned as alpha v1 by it's own definition of such terms. If you are interested in contributing please either submit an issue to [the repository for this blog](https://github.com/code-ape/website) or email me as detailed on [the contact section of the about page](/about/#contact).*

# Introduction

In the world of software projects, code lives a lifecycle. It is developed, released, packaged, used, and finally decommissioned[^decommissioned]; often to be replaced by a successor from the same project.
Many developer practices that attempt to capture this lifecycle focus on semantics for expressing what occurs between snapshots of a project over time.
This, done poorly or done well, inevitably leads to Version Hell.

[^decommissioned]: The decommissioning of software may be official, such as via a stated support window, or unofficial, such as via project abondonment.

For users of a software project, Version Hell occurs when the user wants to use mutliple, different versions of a project at once.
For developers of a software project, Version Hell occurs when a project has many versions which all must be maintained with varying degrees of support and new features.
These problems are directly related. Users of projects want to use new featues but don't want to upgrade because it will break existing uses. Meanwhile, developers of projects want to work on new features but don't want to support many different versions of their project.

This document describes a novel means of solving this problem, called Lifecycle Versioning, which makes the context of a software project's interface explicit and available to users in a way that is preserved as new features are added.
This is achieved by implementing two things: API Version Namespaces and Interface Lifecycle Labels.
Together they allow for all versions (as defined below) of a project to exist together and the interface of each to be explicit about the promises it makes related to stability and support.
In doing this the many different releases that developers find themselves dealing with in Version Hell become unnecessary as a project simply acretes work over time, for all different versions, and releases are simply snapshots of this.
This also solves the Version Hell experienced by users as updating a dependency which contains a new version will not break their use of the project because versions are namespaced and thus prior versions remain available for use.
In addition to this, the added context what lifecycle "phase" any part of a projects interface is in allows developers to clearly communicate the stability and support of what they publish and thus users may make informed decisions about what parts of a project they do or do not want to use.


# Vocabulary

To help make this document clear to follow, below are three quick definitions for terms which may have somewhat different or unclear meanings for people coming from other common software development practices.

1. **Version:** A means of distinguishing specific implementations of a software which have the same name, and perhaps similar ideas, but are different in ways that break prior implementations promises.
This can be seen when comparing Python 2 to Python 3 along with most other "major version" incrementations of software projects which follow Semantic Versioning.
2. **Release:** A means of distinguishing specific notable states of a project over time.
Generally releases are done either on a time interval or by feature additions.
Under common versioning practices, such as Semantic Versioning, this would include any release which results in an incrementation of either the "minor version" number or "patch version" number.
3. **Release Artifact:** The entity which is distributed for a release that contains the project in the state of the release.
It is generally made publicly available for easy access by users.
In the world of Linux system programming this often results in a `tar` archive which has been compressed with `gzip`, `xz`, or some other widely available lossless compression algorithm.

# Summary: Standard Use Case

Given an interface for usage by others; including but not limited to: software libraries, command line utilities, and HTTP APIs:

1. All versions of an interface should be visible and enumerated at the top level of the interfaces namespace.
1. All features of an interface should be marked as being in one of the following states: `alpha`, `beta`, `stable`, or `retired`.
1. The following changes are allowed for a feature with each state:
    * `alpha`: may be modified, transitioned to `beta`, or deleted.
    * `beta`: may be modified, transitioned to `stable` with a support interval, `alpha`, or deleted.
    * `stable`: may be patched for implementation bugs that violated its stated function, have its support interval extended, or be transitioned to `retired`.
    * `retired`: may never be transitioned.
1. Each possible state is for the following uses and makes the following promises:
    * `alpha`
        * **Purpose:** for new features to be created for inital feedback from users.
        * **Promises:** none, the feature may not work and may be deleted at any time.
    * `beta`
        * **Purpose:** for completed features to go for evaluation from users before being made stable.
        * **Promises:** features should have precise descriptions of what they do and work as stated, since they are for feedback before going to stable. It still has no support interval and may be deleted at any time.
    * `stable`
        * **Purpose:** for finalized features that have made it through `alpha` and `beta`.
        * **Promises:** `stable` features should have a precise description of what they do and are supported through their stated support interval. This means they will be patched for security and implementation bugs, but otherwise remain unchanged. All patches should have no percievable effect on the interface and not change its description. If such a patch would have such effects then a new feature should be made instead.
    * `retired`
        * **Purpose:** features which will not be supported any more after their support interval ends.
        * **Promises:** once a feature is marked as `retired` it will still be supported through its support interval and should be considered stable by users until then.
        This allows the interface maintainers to communicate changes ahead of their effect, i.e. let users know an interface will be unsupported in 6 months.
        Use of `retired` features past their support interval should require a manual acknowledgement from users that they are using unsupported features.
1. Releases of software that uses Lifecycle Versioning should simply include the date the release represents using ISO 8601 (example: `2017-05-16`).
1. Lifecycle Versioning discourages having different "releases" of a project because all stages of features should be in each release over time for users to use as they see fit.
For cases where this isn't possible and multiple releases are required, such as for forks or different branches of a Git repository, the release name should include a namespace prepending it for "fork"-like situations and a "tag" following it for "branch"-like situations. For example: `ferris/my_lib` would be my fork of `my_lib`, a more verbose example (if justified) is `my_company/ferris/my_lib:team_A/dev`.
 
## Examples:

### Library

```
[ ferris/mylib, release 2018-01-02 ]

src/
├── v01/
|   ├── foo (stable, supported 2016-01-01 to 2018-06-01)
|   └── bar (beta)
└── v02/
    ├── foo (retired, supported 2017-01-01 to 2017-09-01)
    ├── fuz (stable, supported 2017-03-01 to 2020-09-01)
    ├── bar (alpha)
    └── baz (stable, supported 2017-04-01 to 2020-09-01)
```

# Philosophy

Lifecycle Versioning is based on the following four values:

1. **Explicity:** The context and promises of an interface should be explicit between its creators and users.
1. **Transparency:** The context and promises of an interfaces should be made clearly and easily visible to users without obfuscation.
1. **Immutability:** The context and promises of an interface should be non-retractable and enforced as such.
1. **Accretion:** An interface should exist as a single inextricable enitity which can only accrete promises. It should never be divided such that there are multiple entites of an interface which have the same name but different promises.

Together, these four values maximize the utility of software over time.
They also encourage updating software frequently because all users have no concerns that the interfaces they use will disappear of change with upgrades. In addition to this, frequently updating ensures users have an up to date context for interfaces.
This helps them make informed decisions about how they can best use it over time.

# Implementation

To achieve the four philosophical principles of Lifecycle Versioning the following two practices are used.

## API Version Namespaces

All interfaces (often referred to as APIs), whether for a library, an executible, or a service, should use namespaces for each version.
Once a namespace has stable features in it, neither it nor the features can be removed, only made post-stable and then retired.

In doing this software projects can be consolidated as "versions" of projects simply recieve unique namespaces, generally in the form of an incrementing counter (example: `v01`, `v02`, etc).
This means there is no longer multiple different branches or artifacts related to versions which must be maintained seperately.

## Interface Lifecycle Labels

Developers should explicitly label each interface component with a state relating to its stability and an associated timeline if applicable for the labelled state.

In doing this software projects can be consolidated as different "stabilities" of software can be included together because each recieves an appropriate stability label.
This means there is no longer a need seperating different stages of a project, such as having an "alpha", "beta", and "stable" branches or their corresponding release artifacts.

# Example

Let's walk through a project undergoing changes via Lifecycle Versioning

For example: project mylib can start with namespace v01 and three alpha features:

```
[ mylib on 2017-09-01 ]

v01/
├── run  (alpha)
├── walk (alpha)
└── stop (alpha)
```

Later, after possible user feedback and more work, two of these features make their way to stable with one year of support while one is removed. This results in the following release.

```
[ mylib, release 2018-01-01]

v01/
├── run  (stable, lifetime: 2018-01-01 to 2019-01-01)
└── stop (stable, lifetime: 2018-01-01 to 2019-01-01)
```

Then, half way through that year, this project's developers want to create a new API which is incompatible with the current one. Resulting in `v02/` being created and the following release.

```
[ mylib, release 2018-01-01]

v01/
├── run  (stable, lifetime: 2018-01-01 to 2019-01-01)
└── stop (stable, lifetime: 2018-01-01 to 2019-01-01)
v02/
├── run      (beta)
├── fly      (alpha)
├── teleport (alpha)
└── stop     (beta)
```

Towards the end of that year they decide to extend the lifetime of `v01/` another half year, stabilizing `v02/run` and `v02/stop` and bringing `v02/fly` and `v02/teleport` to beta.
They choose to release this as well as there is no reason not to.

```
[ mylib, release 2018-01-01]

v01/
├── run  (stable, lifetime: 2018-01-01 to 2019-06-01)
└── stop (stable, lifetime: 2018-01-01 to 2019-06-01)
v02/
├── run      (stable, lifetime: 2018-09-01 to 2019-09-01)
├── fly      (beta)
├── teleport (beta)
└── stop     (stable, lifetime: 2018-09-01 to 2019-09-01)
```

On 2019-05-29, it is published that `v01/run` and `v01/stop` have will become retired at their marked end of lifetime: 2019-06-01.
The lifetimes of `v02/run` and `v02/stop` have also been increased to `2020-01-01`
Also, after more feedback `v02/teleport` is rewritten and labelled as alpha.

```
mylib on 2019-05-29:
v01/
├── run  (retired [marked 2019-05-29], lifetime: 2018-01-01 to 2019-06-01)
└── stop (retired [marked 2019-05-29], lifetime: 2018-01-01 to 2019-06-01)
v02/
├── run      (stable, lifetime: 2018-09-01 to 2020-01-01)
├── fly      (beta)
├── teleport (alpha)
└── stop     (stable, lifetime: 2018-09-01 to 2020-01-01)
```

On 2019-08-01, after more feedback and work on `v02/fly` and `v02/teleport` they stabilize them and increase the lifetime of `v02/run` and `v02/stop` to `2022-01-01`.

```
mylib on 2019-08-01:
v01/
├── run  (retired [marked 2019-05-29], lifetime: 2018-01-01 to 2019-06-01)
└── stop (retired [marked 2019-05-29], lifetime: 2018-01-01 to 2019-06-01)
v02/
├── run      (stable, lifetime: 2018-09-01 to 2022-01-01)
├── fly      (stable, lifetime: 2019-08-01 to 2022-01-01)
├── teleport (stable, lifetime: 2019-08-01 to 2022-01-01)
└── stop     (stable, lifetime: 2018-09-01 to 2022-01-01)
```


# How to express releases of software that use Lifecycle Versioning

Because all feature information is preserved once it becomes stable, releases then have no need to express which version they contain or that version's stability.
Thus releases instead simply contain the name of the project with the date of the release.
Optionally, the time of release may be added as well if projects need to make releases more than once a day, normalized to UTC time and following the [ISO-8601 format](https://en.wikipedia.org/wiki/ISO_8601).

An example of releases as compressed tar files could be the following:

```
mylibrary-2016-11-27.tar.xz
mylibrary-2017-05-16.tar.xz
mylibrary-2017-12-02.tar.xz
```


# Use with Semantic Versioning

The core idea behind Lifecycle Versioning is that software development should accrete features which are seperated into incrementing namespaces where they transition through stages.
However, many package systems for software explicitly use only semantic versioning.
Thus for projects which use semantic versioning the following is recommended:

```
Date of release:
2017-05-16

Translation to semantic versioning and release:
    Version: 2017.05.16
    Release: [ reserved for changes in packaging not related to the project ]

```

# Other benefits

## Simplification of repository management

Often times projects will have multiple API versions that are stable of thus being maintained simultaniously.
Because these different API versions are often seperated in seperate git branches, or the equivelent for other source control systems, applying security or other justifiable patches to these multiple APIs requires moving back and forth between these branches.
Plus applying such patches requires at least one pull request per version.
Using Lifecycle Versioning simplified this process as all versions are visible to the developer.

# Marking Lifecycle Version Labels

Part of the stated value of Lifecycle Versioning is that project interfaces will have their lifecycles explicitly labelled.
This section addresses potential ways of doing this.

Currently, in part becuase this document is still in alpha stage currently and in part because software language are so different from one another, this has yet to be decided.
Feedback on it this topic welcome and appreciated.
Currently the means by which a software language does this should achieve the following two things:

1. Allow for user tooling, at either compile or runtime depending on the language, to select which features and versions they do or do not want.
2. Document a log of all label transitions so that both users may see them in the documentation and tooling may scan them to verify historical correctness.

Below is an example of how this may be implemented, in part, for the Rust programming language.

```
2017-08-29: alpha
2017-10-05: beta
2017-11-11: alpha
2017-12-29: beta
2018-03-01: stable, end date 2020-03-01
2019-07-01: extend stable, end date 2021-07-01
2021-06-01: retired
```

## Rust example

This example looks as a feature's progression over time.
This is still a work in progress and feedback is welcome.

Initial creation of the `teleport` feature with an alpha label.

```rust
/// Lifecycle log
/// 2017-06-12T05:58:09Z alpha
#[cfg(feature = "alpha")]
fn teleport(h: &Human, l: &Location) {
    ...
}
```

Transition of the `teleport` feature to a beta label. 

```rust
/// Lifecycle log
/// 2017-06-12T05:58:09Z alpha
/// 2017-07-24T09:12:59Z beta
#[cfg(feature = "beta")]
fn teleport(h: &Human, l: &Location) {
    ...
}
```

Example of what the `teleport` feature look like having gone through an entire lifecycle thus resulting in it being retired.

**Open Question: How to express date to compiler for it to still consider `teleport` stable until 2019-06-12?**

```rust
/// Lifecycle log
/// 2017-06-12T05:58:09Z alpha
/// 2017-07-24T09:12:59Z beta
/// 2017-10-06T08:01:48Z stable, ends 2018-06-12T00:00:00Z
/// 2018-04-12T12:33:27Z stable, ends 2019-06-12T00:00:00Z
/// 2019-03-01T05:41:05Z retired
#[cfg(feature = "retired")]
fn teleport(h: &Human, l: &Location) {
    ...
}
```

# FAQ

* **What about features which are past their lifetime but haven't been marked as retired?**
    * This should not happen, but is none-the-less possible for projects where development efforts are intermittent. In such circumstances use of features should be treated as retired with the warning message stating "assumed retired" instead of "marked retired". Note that retirement can be marked prior to the date of being retired to avoid any limbdo period.
* **What if I don't ever want to make the promises that are needed to make features stable?**
    * Simply keep features as `beta` and `alpha`, or whatever specifier you choose, indefinitely. There's nothing wrong with this if it's the truth for the state of your software. Many `beta` software projects are used in the software world today, the users of them simply inherit the risk that the software they are using makes no promises.
* **How do I blame version labels?**
    * You should use your version control for blame of versioning.
* **How is enforcement done to ensure projects are following Lifecycle Versioning?**
    * To do this CLI tools should be created that can be coupled with development and release process (git hooks and build processes). Theses tools should be able to validate commit chains: either current work versus the last commit, all commits within a range, etc.

