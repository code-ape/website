+++
title = "B+ Tree in Rust, Part 1: In Memory"
date = "2017-11-15"
categories = ["Technical Article"]
tags = ["Rust Language", "Data Structures"]
draft = true

summary = '''
TODO
'''

repository = "TODO"
+++

Data structures are fundemental to solving most any problem with software.
Because of this, we tend to take them for granted.
But, their design and implementation are rarely simple things.
This is in part because they must be higher performant, else entire software applications can be dramatically slowed by them.
This is also in part because they force us to deal with the bare, low level aspects of of software; namely the IO boundaries of whatever our data structure is located.
This post will walk through implementing a performant, in-memory B+ Tree using Rust.
This post assumes the reader has a basic aptitude for writing Rust code, though no prior knowledge of writing software using unsafe Rust is required.

# B+ Trees in Rust, Part 1

For those of you with a basic familiarity with Rust and B+ Trees, you likely already see where this post is headed: `unsafe` territory.
This is because Rust has the concept of ownership, meaning any struct, enum, etc. in Rust must owned at any given time by a scope or another entity.
However, like doubly linked lists, B+ Trees do not follow a simple tree like means of ownership.

# B+ Trees, a crash course

B+ Trees are a special implementation of a B Tree which is a generalization of a binary search tree.

# Laying out the project

To begin with create a cargo project.

```
$ cargo new bptree
$ cd bptree
```

Use immutable versioning:

```
$ mkdir src/v1
$ touch src/v1/mod.rs
$ echo "pub mod v1;" > src/lib.rs
```


