+++
title = "Lifecycling Versioning Philosophy: TODO"
date = "2018-02-02"
categories = ["Technical Article"]
tags = ["Software Development"]
draft = true

summary = '''
TODO
'''

repository = "TODO"
+++

Current tools and techniques of software development evolution, such as version control systems (i.e. Git) and release naming conventions (i.e. Semantic Versioning), have become the standard for how software development evolution is done.
However, in their rise to near ubiquity, such systems have caused the problem space of software development evolution to fade from commonplace discussion and thought.
This post is an analysis of the software development evolution problem space and a proposal for a new philosophy which improves on current paradigms.

# Introduction

The practice of software development has some unique aspects to it, namely: time, evolution, and perspective.
This is because software lives a web-of-life style of existance.
As things happen in the world the software that serves the world must react with it.
Whether this be engineer software which must accomidate a way use new simulation algorithms, banking software which must include complicance to new regulations, server side software which must fix newly discovered vulnerabilities, or an operating system which wants to take advantage of new hardware features; the three statements remain true:

1. Software evolves.
2. It evolves with time.
3. Being able to perceive this is useful. 

## Time

Version control systems are useful for a number of reasons, but at it's heart version control systems are meant to capture time.
While different version control systems have different details for doing this, they all allow a user to request to see the state of the repositories code at a given time.
Modern version control systems, like Git, offer other ideas in addition to this, like branches, to make it more useful but the core idea still remains at Git's core.

## Growth and Breakage

Many people want to say that software changes with time.
I understand what is meant by this, but I don't think "change" is the correct word to use to capture this process.
To say software "changes" is to say that at any two points in time a piece of software may be different.
But what those differences are is not expressed.

Let's look at Python as a useful, though not unique, example.
We say that the Python programming language "changed" with each release.
But very different things "changed" between release 2.6 and release 2.7 compared to release 2.7 and release 3.5.
From release 2.6 to 2.7 things changed about the langauge, but your Python project probably "worked" on Python 2.7 (more on the phrase "worked" later on in this article).
However, even though your project "worked" on 2.7 there's a very real chance it didn't work on 3.6 without needing to change things about it.
We've become use to such things, we use words like "minor release" and "major release" to try and smooth over just how different these two cases are, but they are clearly quite different!
To add to this, even though using Python 3.6 likely requires us to change things about our project for it to "work", we still have expectations about it.
If running our program on Python 2.7 resulted in a HTTP web server and running the appropriate version of it on Python 3.6 resulted in it printing out the SHA256 sum of our source file, we'd all say that something was very wrong with our `python36` executable as it seems to be behaving a lot like the `sha256sum` executable.
Under no circumstances would someone agree that such a "change" makes any sense.

Rich Hickey, the creator of the Clojure programming language, captured this well in his [Clojure/Conj 2016 talk *Spec-ulation*](https://www.youtube.com/watch?v=oyLBGkS5ICk) in which he stated that software either grows or breaks over the progression of time.
By this Python grew from release 2.6 to release 2.7 but broke from release 2.7 to release 3.6.

To highlight this, and nail down the specifics of the word "grow" and "break", let's look at the meaning of `print` and `asyncio` from release 2.7 to release 3.6.
In Python 2.7 `print` was a statement meaning that the following was valid code:

```python
print "Hello"
```

This was "changed" between Python release 2.7 and release 3.6 so that `print` is now a function, meaning the above usage will crash and it must be replaced by this:

```python
print("Hello")
```

By this we say that `print` broke from release 2.7 to release 3.6.
This is because it was overwritten.
Its name didn't change, both releases have a `print`, but they refer to different things.
And that's the problem with breaking software, we write programs that use some API and then that API changes which at best changes what our program does and at worst makes it meaningless and thus do nothing.

Let's contrast this with growing software.
Something else that happened between those releases was the addition of the `asyncio` module as part of the language.
Unlike what happened with `print`, the `asyncio` module didn't replace or overwrite something that previously existed.
By this, the addition of `asyncio` was something that grew the software of Python.

But, despite the fact that some things grew and some things broke between Python release 2.7 and release 3.6, we still would say that Python broke between the releases.
In fact, no matter how much growth occurred for Python between these releases and how little broke, so long as even one thing broke then Python broke between these releases.
Because any time breaks occur in software the people who use it have to go back, reread your documentation, figure out what broken, redo their software which uses yours, and then try to validate that their now updated software still does the same functionality it use to.
And that's something we, as creators and maintainers of software, should avoid doing when possible because it sucks!
Python 3 was released in December of 2008 and took over 8 years for it to be adopted by 1/2 of the Python community, [according to JetBrains](https://twitter.com/pycharm/status/865659029460209664).


## Perspective

Git is useful because, as stated previously, it allows for us to capture the state of code at different points in time.
However, one thing Git doesn't do is 

# Lifecycles

In 2020, Python 2 will reach its end of life and become unmaintained.
Interestingly, this isn't something normally captured in any publishing of software.


- when it was written
- life cycle stage: stable, etc.
- support window

# What is an API?

Suppose you need to use an API, be it a library API or an HTTP REST API, for an important project.
What things would you want to know about it before using it?
You'd probably want to know if it was maintained and, if so, how long it would be maintained into the future.
You'd also probably want to have some promises about it's stability.
If the functionality of calling `foo` changed weekly then that would be a cause for concern.

Likewise, if you did use this API and a new "release" of it came out, you'd have the questions from above along with others: What is the difference between these two releases? Can I safely upgrade to the newest release? And what promises does this new release make about support and stability?

These are all important questions for you, as the consumer of this API.
However, they're also questions which aren't guarenteed to have an answer and, if they do, such answers aren't a fundemental part of the release that can be programmatically checked.
Instead such answers are usually posted on a webpage or in the README file.

# Capturing Lifecycles

When you add something to an API, there's generally some idea of the stage of that piece.
Often times we only work with "stable" releases that are currently supported.
Meaning that such a release should behave in a predictable way and someone is actively making sure it works the way it is intended to, until some future date, even as things like newly discovered security vulnerabilities or new hardware releases occur.

We also say that software will, at some point, be no longer supported.
Generally we refer to this by saying a piece of software has reach its end of life, EOL, or been depreciated.

On the flip side we also have software which is in its lifecycle prior to becoming "stable".
Such software can be tagged by a number of different terms depending on the project.
These include: development, beta, alpha, nightly, and release candidate (RC).


# The API Release Problem

One issue with how releases are done with APIs currently is that all concepts around the stability, support, and composibility of an API are generally tied to a release.
We say that an entire API is either stable or beta or depreciated.
This makes hopping from API releases challenging as such a mindset, from a developers perspective, encourages breaking changes.

In addition to this, generally APIs can not be composed across releases.
Most programming languages don't allow you to continue to use release X of a library across most of your project while using release Y for new development.
This means that, as a consumer of APIs, changing releases becomes an all or nothing undertaking which could be potentially disasterous if some functionality in release X is no longer present in release Y.

# Flattening time: version namespaces

The fundemental issue here is that when you use release Y, then you have no access to any prior releases and likewise when you move to a successor of release Y then you will no longer have access to it.

To remidy this I propose using version namespaces.
Version namespaces allows a developer to create a new version of a library which can be released with all prior versions still accessible.

Because of this compatibility between versions is also possible. For example, version 3 of a library could have a function for converting a some data types from version 2 to their appropriate forms to work with the version 3 code.
By this upgrade paths become much for compelling and accessible.

# Releases: just time snapshots

With all releases containing all versions relative to when they're released, thanks to version namespacing, releases then become a representation of an entire project at any given point in time.

Thus upgrading to a newer release can only make new features available across all given versions.

