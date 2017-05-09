+++
title = "eBPF, part 2: Syscall and Map Types [DRAFT]"
date = "2017-05-04"
tags = ["eBPF", "BPF", "Networking", "Linux"] 
version = 1

summary = '''
TODO
'''
+++


# eBPF, part 2

This article is the second in a series on eBPF.
It builds upon the previous article, ["eBPF, part 1: Past, Present, and Future"]({{< ref "ebpf_past_present_future.md" >}}), by diving into the core of using eBPF: the Linux `bpf` syscall.
In doing so this article hopes to offer a completely fleshed out depiction of the core machinery one must use for utilizing eBPF.

As I mentioned in the prior article, eBPF has rapidly been integrated into many Linux kernel components.

Due to this sprawling state of eBPF, this article is fairly lengthly and reads like a compendium at parts.

*This article also references future articles that will be written for this series. For those who may cite this article, it will be updated to reference said articles when they are posted. However, previous versions of this article will be accessible for reference and links to them will be posted on this page.*


# Intro

In the previous article, ["eBPF, part 1: Past, Present, and Future"]({{< ref "ebpf_past_present_future.md" >}}), the process of using an eBPF program was summarized into three steps.

1. Creation of the eBPF program as byte code.
2. Loading the program into the kernel and creating necessary eBPF-maps.
3. Attaching the loaded program to a system.

Due to the many different applications of eBPF, the details of step 1, creating the eBPF program, and step 3, attaching it to a system in the kernel, vary by use case.
This is part of the confusion that arises from some eBPF tutorials because they walk readers through all three of these steps for a single use case of eBPF.
However the core of eBPF, and thus what all applications of it have in common, is step two.

No matter the use case, an eBPF program must be loaded into the kernel and eBPF-maps, if used, must be configured for it.
This is all done by the Linux `bpf` syscall, which is basis for this particular article.


# Clarifications, Terms, and Corrections

This article maintains the same stance on clarifications, terms, and corrections as the first in its series.
Thus, for concision, this article will not repeat it.
For those looking to for more information on such matters please refer to 
section titled ["Clarifications, Terms, and Corrections" from the first article]({{< ref "ebpf_past_present_future.md#clarifications-terms-and-corrections" >}}).


## Terms

This article builds on the terms from the subsection titled ["Terms" from the first article]({{< ref "ebpf_past_present_future.md#terms" >}}).
For those looking for clarification on terms not defined below, please check with the section from the original article.
If you feel that a term is missing please request a clarification as outlined in the ["Clarifications, Terms, and Corrections" from the first article]({{< ref "ebpf_past_present_future.md#clarifications-terms-and-corrections" >}}).

* **Syscall:** Common shorthand for "system call". It refers to the programmatic interface that user programs use to request things from the operating system. This article prefers to use "syscall" over "system call" due to it being the more standard term in current writing.
* **Linux `bpf` syscall:** The syscall found in the Linux operating system for using eBPF.


# The Linux bpf syscall

When eBPF was first added to the Linux kernel, with version 3.18, what was technically added was the `bpf` syscall along with the underlying machinery in the kernel.
The [release notes on the Linux `bpf` syscall](https://kernelnewbies.org/Linux_3.18#head-ead251efb6bbdbe2922e7c6bd0c7b46342e03dad) capture eBPF and its technical implementation quite well.
For those not interested in reading the release notes, the parts which are relevant for this particular article are as follows.
Note that some details of this have changed since eBPF's initial release.

> bpf() syscall is a multiplexor for a range of different operations on eBPF
...
eBPF "extends" classic BPF in multiple ways including ability to call in-kernel helper functions and access shared data structures like eBPF maps.
...
They [eBPF programs] are loaded by the user process and automatically unloaded when process exits.
Each eBPF program is a safe run-to-completion set of instructions.
eBPF verifier statically determines that the program terminates and is safe to execute.
... programs may call into in-kernel helper functions which may, for example, dump stack, do trace_printk or other forms of live kernel debugging.


In diving into this syscall one would expect to look where documentation for Linux syscalls usually resides: in a section 2 man page.[[^section_2_man_page]]
This syscall, as with most Linux syscalls, does have [a man page](http://man7.org/linux/man-pages/man2/bpf.2.html).
Sadly, however, some aspects of it are vastly out of date as of this writing.
In fact, from the git logs for the [Linux man pages](https://git.kernel.org/pub/scm/docs/man-pages/man-pages.git) it appears that the last notable contribution of new information to the man page was on **July 30, 2015**, over a year and nine months ago.[[^last_bpf_man_addition]]
Thankfully, however, the majority of the outdated information is related to the types of eBPF programs and eBPF-maps that exist.
These missing details do, of course, exist in the Kernel code and thus this article makes references to Linux kernel code at times since is the source of truth for eBPF's implementation.
For reference, this article will use the code of the most recent Linux kernel release, version [4.11](https://github.com/torvalds/linux/tree/v4.11).

[^section_2_man_page]: For those unfamiliar with what a "section 2 man page" is, man pages are short for "manual pages" and are commonly used on Unix and Unix-like operating systems for documentation. Section 2 man pages are for system calls (syscalls). 

[^last_bpf_man_addition]: This addition was done by Daniel Borkmann in commit `9a818dddcffce642126c4d8389ad679554617fc4` to the Linux [man-pages repository](https://git.kernel.org/pub/scm/docs/man-pages/man-pages.git/).

As of 4.11 there are two files directly related to using eBPF from user-space.
Each path listed below refers to a file in the kernel repository and links to the file it references.

* [`kernel/bpf/syscall.c`](https://github.com/torvalds/linux/blob/v4.11/kernel/bpf/syscall.c):
The Linux kernel code related to the `bpf` syscall.
* [`include/uapi/linux/bpf.h`](https://github.com/torvalds/linux/blob/v4.11/include/uapi/linux/bpf.h):
The `bpf` header file for assisting in using the `bpf` syscall.

The Linux `bpf` syscall has the following signature:

```C
// From the macro expansion of the following code:
// https://github.com/torvalds/linux/blob/v4.11/kernel/bpf/syscall.c#L1031

int bpf(int cmd, union bpf_attr *attr, unsigned int size);
```

Note the use of the `bpf_attr` union.
This is a C union which allows for different C structs to be passed to the `bpf` syscall depending on which command is being used.
The code for it can be found in the [`include/uapi/linux/bpf.h`](https://github.com/torvalds/linux/blob/v4.11/include/uapi/linux/bpf.h#L148) file of the Linux kernel.
The relevant C struct from this C union will be included in code examples that use the `bpf_attr` union so readers can see the form of the struct being used.


# eBPF commands

To begin with let's look at the ten commands for the `bpf` Linux syscall.
Of those ten, six are listed in the man page: `BPF_PROG_LOAD`, `BPF_MAP_CREATE`, `BPF_MAP_LOOKUP_ELEM`, `BPF_MAP_UPDATE_ELEM`, `BPF_MAP_DELETE_ELEM`, and `BPF_MAP_GET_NEXT_KEY`.
Of these documented commands there are really only two types: loading an eBPF program and various manipulations of eBPF-maps.
The eBPF-map operations are fairly self descriptive and are used to create eBPF-maps, lookup an element from them, update an element, delete an element, and iterate through an eBPF-map (`BPF_MAP_GET_NEXT_KEY`).

A quick look at the [`bpf_enum` in `include/uapi/linux/bpf.h`](https://github.com/torvalds/linux/blob/v4.11/include/uapi/linux/bpf.h#L73) shows the four other commands: `BPF_OBJ_PIN`, `BPF_OBJ_GET`, `BPF_PROG_ATTACH`, `BPF_PROG_DETACH`.
All together this gives us the following 10 commands.

```c
// From https://github.com/torvalds/linux/blob/v4.11/include/uapi/linux/bpf.h#L73

enum bpf_cmd {
    BPF_MAP_CREATE,
    BPF_MAP_LOOKUP_ELEM,
    BPF_MAP_UPDATE_ELEM,
    BPF_MAP_DELETE_ELEM,
    BPF_MAP_GET_NEXT_KEY,
    BPF_PROG_LOAD,
    BPF_OBJ_PIN,
    BPF_OBJ_GET,
    BPF_PROG_ATTACH,
    BPF_PROG_DETACH,
};
```

*These calls form the basis of what is possible for a user to do with the eBPF system by itself. Of course, this isn't super useful without the context of the systems eBPF can be used with.
The third article in this series will be devoted to that topic, the systems eBPF can be used with, and this article will be updated to reference it when it is published.*

These `bpf` syscall commands aren't hugely descriptive in their abbreviated form.
And thus this article will walk through them.

## `BPF_PROG_LOAD`

To begin with, the `BPF_PROG_LOAD` command is used for the loading an eBPF program into the Linux kernel and is straightforward to use.
It requires the type of eBPF program, the array of eBPF virtual machine instructions, the license associated with the filter, a log buffer for messages from validating the filter code, and the log level for those messages.
There are, as of this writing, twelve different types of eBPF programs.
These types correspond to different uses of eBPF and, as stated above, will be covered by the third article in this series.

The Linux `bpf` syscall does offer an [example of a function in C](http://man7.org/linux/man-pages/man2/bpf.2.html) which does this.

```C
//// member of bpf_attr union for BPF_PROG_LOAD
//
//  struct { /* anonymous struct used by BPF_PROG_LOAD command */
//      __u32       prog_type;  /* one of enum bpf_prog_type */
//      __u32       insn_cnt;
//      __aligned_u64   insns;
//      __aligned_u64   license;
//      __u32       log_level;  /* verbosity level of verifier */
//      __u32       log_size;   /* size of user buffer */
//      __aligned_u64   log_buf;    /* user supplied buffer */
//      __u32       kern_version;   /* checked when prog_type=kprobe */
//  };

char bpf_log_buf[LOG_BUF_SIZE];

int
bpf_prog_load(enum bpf_prog_type type,
              const struct bpf_insn *insns,
              int insn_cnt,
              const char *license)
{
    union bpf_attr attr = {
        .prog_type = type,
        .insns     = ptr_to_u64(insns),
        .insn_cnt  = insn_cnt,
        .license   = ptr_to_u64(license),
        .log_buf   = ptr_to_u64(bpf_log_buf),
        .log_size  = LOG_BUF_SIZE,
        .log_level = 1,
    };

    return bpf(BPF_PROG_LOAD, &attr, sizeof(attr));
}
```


## `BPF_MAP_CREATE`

Next, there are the five map operations.
Here we encounter another term which has been outgrown by its evolution.
As of this writing, eBPF has eleven types of "maps", which will be expanded upon in the ["eBPF-map types" section](#ebpf-map-types) later on in this article.
For the moment simply know that eBPF offers different data structures that are generally either hash maps or arrays.
A number of specialized variants of these exist for more specialized circumstances.
This article will use the term "eBPF-map" to refer to the all of these different data structures eBPF offers for storing state.

Creating a map only requires the type of eBPF-map desired, the size of a key, the size of a value, the maximum number of entries, and whether or not to pre-allocate the map in memory.

Again, the Linux `bpf` syscall does offer an [example of a function in C](http://man7.org/linux/man-pages/man2/bpf.2.html) which does this.
Though this example isn't helpful in providing context for how to create some eBPF-map types.
The clearest example of this is for eBPF-map types that are arrays where it seems counter-intuitive to specify the key size.
The creation and lookup of the eBPF-map types will be covered in their respective sections later on in this article.


```C
//// member of bpf_attr union for BPF_MAP_CREATE
//
//  struct { /* anonymous struct used by BPF_MAP_CREATE command */
//      __u32   map_type;   /* one of enum bpf_map_type */
//      __u32   key_size;   /* size of key in bytes */
//      __u32   value_size; /* size of value in bytes */
//      __u32   max_entries;    /* max number of entries in a map */
//      __u32   map_flags;  /* prealloc or not */
//  };

int
bpf_create_map(enum bpf_map_type map_type,
               unsigned int key_size,
               unsigned int value_size,
               unsigned int max_entries)
{
    union bpf_attr attr = {
        .map_type    = map_type,
        .key_size    = key_size,
        .value_size  = value_size,
        .max_entries = max_entries
    };

   return bpf(BPF_MAP_CREATE, &attr, sizeof(attr));
}
```

The `BPF_MAP_CREATE` variant of the `bpf_attr` union has five fields but the context of them is missing some information, specifically for `map_entries` and `map_flags`.

It's not stated what the cap on `max_entries` is, however, since it is represented by an unsigned 32 bit integer it can't be more than 2^32 which is 4,294,967,296.
Some examples of using eBPF, found in the Linux kernel repository, [create a 1,000,000 entry map](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/tracex4_kern.c#L21), which is likely larger than most users will ever need.
For reference, use of super high capacity eBPF-maps should be used carefully  due to memory usage.
The memory foot print for 2^32 pairs of 64 bit keys and 64 bit values comes out to 64GiB![[^max_ebpf_memory]]

[^max_ebpf_memory]: This comes from (2^32)*(64 bits + 64 bits), Wolfram Alpha calculation: [https://www.wolframalpha.com/input/?i=(2%5E32)(64+bits+%2B+64+bits)+to+GiB](https://www.wolframalpha.com/input/?i=(2%5E32)(64+bits+%2B+64+bits)+to+GiB)

This related to the `map_flags` option.
This appears to have been added in version 4.6 of the Linux kernel which was released in May 2016.
This flag allows for users to decide whether or not to pre-allocate the eBPF-map.
Reading through the commit that added this, [6c90598174322b8888029e40dd84a4eb01f56afe](https://github.com/torvalds/linux/commit/6c90598174322b8888029e40dd84a4eb01f56afe), shows that this was needed for when using eBPF with kprobes.
However, there may be other times when this is needed or desired, such as to always run with the eBPF-map fully allocated in memory to avoid having to worry about exhausting available memory.

## `BPF_MAP_LOOKUP_ELEM`, `BPF_MAP_UPDATE_ELEM`, and `BPF_MAP_DELETE_ELEM`

As their names indicate, these eBPF commands are used for getting, setting, and deleting entries in eBPF-maps.
These all involve constructing the same C struct from `bpf_attr` union, though this has a union inside itself which will always be the `value` option in these cases.

Overall, these commands are extremely straightforward.
The return codes are documented on the [`bpf` syscall man page](http://man7.org/linux/man-pages/man2/bpf.2.html).

```C
//// member of bpf_attr union for BPF_MAP_LOOKUP_ELEM, BPF_MAP_UPDATE_ELEM, 
//// and BPF_MAP_DELETE_ELEM
//
//  struct { /* anonymous struct used by BPF_MAP_*_ELEM commands */
//      __u32       map_fd;
//      __aligned_u64   key;
//      union {
//          __aligned_u64 value;
//          __aligned_u64 next_key;
//      };
//      __u64       flags;
//  };

int
bpf_lookup_elem(int fd, const void *key, void *value)
{
    union bpf_attr attr = {
        .map_fd = fd,
        .key    = ptr_to_u64(key),
        .value  = ptr_to_u64(value),
    };

    return bpf(BPF_MAP_LOOKUP_ELEM, &attr, sizeof(attr));
}


int
bpf_delete_elem(int fd, const void *key)
{
    union bpf_attr attr = {
        .map_fd = fd,
        .key    = ptr_to_u64(key),
    };

    return bpf(BPF_MAP_DELETE_ELEM, &attr, sizeof(attr));
}
```

The `BPF_MAP_UPDATE_ELEM` command also allows a flag to be specified which communicates the desired action relative to if a key does or doesn't already exist when the update action is called.


```C
//// From https://github.com/torvalds/linux/blob/v4.11/include/uapi/linux/bpf.h#L134
//
//  /* flags for BPF_MAP_UPDATE_ELEM command */
//  #define BPF_ANY     0 /* create new element or update existing */
//  #define BPF_NOEXIST 1 /* create new element if it didn't exist */
//  #define BPF_EXIST   2 /* update existing element */

int
bpf_update_elem(int fd, const void *key, const void *value,
                uint64_t flags)
{
    union bpf_attr attr = {
        .map_fd = fd,
        .key    = ptr_to_u64(key),
        .value  = ptr_to_u64(value),
        .flags  = flags,
    };

    return bpf(BPF_MAP_UPDATE_ELEM, &attr, sizeof(attr));
}
```

## `BPF_MAP_GET_NEXT_KEY`

```C
//// member of bpf_attr union for BPF_MAP_LOOKUP_ELEM, BPF_MAP_UPDATE_ELEM, 
//// and BPF_MAP_DELETE_ELEM
//
//  struct { /* anonymous struct used by BPF_MAP_*_ELEM commands */
//      __u32       map_fd;
//      __aligned_u64   key;
//      union {
//          __aligned_u64 value;
//          __aligned_u64 next_key;
//      };
//      __u64       flags;
//  };

int
bpf_get_next_key(int fd, const void *key, void *next_key)
{
    union bpf_attr attr = {
        .map_fd   = fd,
            .key      = ptr_to_u64(key),
            .next_key = ptr_to_u64(next_key),
        };

    return bpf(BPF_MAP_GET_NEXT_KEY, &attr, sizeof(attr));
}
```

## `BPF_OBJ_PIN` and `BPF_OBJ_GET`

After this we have the currently undocumented commands related to pinning objects (`BPF_OBJ_PIN`), getting objects (`BPF_OBJ_GET`), attaching programs (`BPF_PROG_ATTACH`), and detaching programs (`BPF_PROG_DETACH`).


Tracing through the history in the repository, one can find that `BPF_OBJ_PIN` and `BPF_OBJ_GET` were added in  version 4.4 of the Linux kernel.[[^ebpf_pin_commit]]
The release notes for version 4.4 state that two eBPF features were added: "unprivileged eBPF" and "persistent eBPF programs".[[^linux_4.4_release_notes]]
The `BPF_OBJ_PIN` command relates to the persistent eBPF programs feature of version 4.4 of the Linux kernel.
With this the Linux kernel features a new minimum file system located at `/sys/fs/bpf` which can hold eBPF-maps or eBPF programs.
This is useful before, prior to this, all eBPF-maps and eBPF programs were tied to the program that created them.
Thus it wasn't possible to have a tool create an eBPF program and exit because that would cause the filter to be destroyed.
This addition allows for eBPF-maps and eBPF programs to persist after the program that creates them exits.
Because a file system is used for this, eBPF-maps and eBPF programs are pinned to a path in the file system.
This command thus only needs the file descriptor of what to pin and the path to pin it at.

[^ebpf_pin_commit]: They were contributed by Daniel Borkmann and David S. Miller with commit [` b2197755b2633e164a439682fb05a9b5ea48f706`](https://github.com/torvalds/linux/commit/b2197755b2633e164a439682fb05a9b5ea48f706).

[^linux_4.4_release_notes]: Linux kernel 4.4 release notes: [https://kernelnewbies.org/Linux_4.4#head-20c20e63018e8fb916fd26476eda2512e2d96632](https://kernelnewbies.org/Linux_4.4#head-20c20e63018e8fb916fd26476eda2512e2d96632)

## `BPF_PROG_ATTACH` and `BPF_PROG_DETACH`

Finally, we have the last two commands `BPF_PROG_ATTACH` and `BPF_PROG_DETACH`.
These commands were actually just added with version 4.10 of the Linux kernel in February of 2017, only two months ago, though they appear to have been written in November of 2016.[[^ebpf_attach_detach_commit]]
The version 4.10 release notes explain that this is used for attaching eBPF programs to cgroups.[[^linux_4.10_release_notes]]
For those not familiar with cgroups, they're a Linux kernel feature used on processes for resource limiting and isolation.
The primary use case for eBPF with cgroups is that filters can be used to accept or drop traffic either to or from processes of a cgroup.

It is worth noting that the eBPF program type `BPF_PROG_TYPE_CGROUP_SOCK` also exists which appears to allow control over which device `AF_INET` and `AF_INET6` sockets are attached to for processes in the designated cgroup.
This is evidence of the possible future of eBPF programs in the Linux kernel, a future where eBPF program are used for injection of non-trivial logic by users into kernel functionality.

[^ebpf_attach_detach_commit]: This was contributed by Daniel Mack with David S. Miller on November 23, 2016 with commit [f4324551489e8781d838f941b7aee4208e52e8bf](https://github.com/torvalds/linux/commit/f4324551489e8781d838f941b7aee4208e52e8bf).
[^linux_4.10_release_notes]: Linux 4.10 release notes: [https://kernelnewbies.org/Linux_4.10](https://kernelnewbies.org/Linux_4.10)


# eBPF-map types

The Linux `bpf` syscall man page mentions three eBPF-map types: `BPF_MAP_TYPE_HASH`, `BPF_MAP_TYPE_ARRAY`, and `BPF_MAP_TYPE_PROG_ARRAY`.
Digging into the [`include/uapi/linux/bpf.h`](https://github.com/torvalds/linux/blob/v4.11/include/uapi/linux/bpf.h#L86) file, however, reveals 11 different types as of Linux kernel 4.11.
Along with this, the Linux kernel reserves the first C enum option as `BPF_MAP_TYPE_UNSPEC` to ensure that zero isn't a valid map type.
Presumably, this is in case zero, with it's many forms in C, does not accidentally get passed as the map types argument. 

```C
// From https://github.com/torvalds/linux/blob/v4.11/include/uapi/linux/bpf.h#L86

enum bpf_map_type {
    BPF_MAP_TYPE_UNSPEC,
    BPF_MAP_TYPE_HASH,
    BPF_MAP_TYPE_ARRAY,
    BPF_MAP_TYPE_PROG_ARRAY,
    BPF_MAP_TYPE_PERF_EVENT_ARRAY,
    BPF_MAP_TYPE_PERCPU_HASH,
    BPF_MAP_TYPE_PERCPU_ARRAY,
    BPF_MAP_TYPE_STACK_TRACE,
    BPF_MAP_TYPE_CGROUP_ARRAY,
    BPF_MAP_TYPE_LRU_HASH,
    BPF_MAP_TYPE_LRU_PERCPU_HASH,
    BPF_MAP_TYPE_LPM_TRIE,
};
```


## `BPF_MAP_TYPE_HASH`

The eBPF-map hash-table, represented by the value `BPF_MAP_TYPE_HASH` in the `bpf_map_type` C enum, is one of the first two map types introduced.
It made it's debut only one minor release after eBPF with version 3.19 of the Linux kernel.[[^ebpf_map_hash_commit]]
Oddly, however, [the release notes](https://kernelnewbies.org/Linux_3.19) make no mention of it.

[^ebpf_map_hash_commit]: It was originally written by Alexei Starovoitov and David S. Miller with commit [0f8e4bd8a1fc8c4185f1630061d0a1f2d197a475](https://github.com/torvalds/linux/commit/0f8e4bd8a1fc8c4185f1630061d0a1f2d197a475) to the Linux kernel.

```C
// Creates an eBPF-map hash-table which associates a `long long` key 
// with a `long-long` value and supports 256 entries.

int map_fd;
long long key, value;

map_fd = bpf_create_map(BPF_MAP_TYPE_HASH, sizeof(key),
                        sizeof(value), 256);
```

## `BPF_MAP_TYPE_ARRAY`

With it's release in August 2015, version 4.2 of the Linux kernel added the eBPF-map type `BPF_MAP_TYPE_ARRAY`.
This is one of the more interesting eBPF-map types because it allows tail calling of eBPF programs!
And, as you may have guessed, the `BPF_MAP_TYPE_ARRAY`

```C
// Creates an eBPF-map array which associates an `int` key 
// with a `long-long` value and supports 256 entries.

int map_fd, key;
long long value;

map_fd = bpf_create_map(BPF_MAP_TYPE_ARRAY, sizeof(key),
                        sizeof(value), 256);
```

## `BPF_MAP_TYPE_PROG_ARRAY`

With it's release in August 2015, version 4.2 of the Linux kernel added the eBPF-map type `BPF_MAP_TYPE_PROG_ARRAY`.
This is one of the more interesting eBPF-map types because it allows tail calling of eBPF programs!
And, as you may have guessed, the `BPF_MAP_TYPE_PROG_ARRAY` holds file descriptors of loaded eBPF programs as its values.
From the man page it's stated that, as of writing, both the key and value must be 4 bytes in size.
Thus the common thing to do is use numbers to identify the different eBPF program types.
With this pattern also comes the `bpf_tail_call` helper function.
This function can be invoked by an eBPF program to lookup a program from an eBPF-map of type `BPF_MAP_TYPE_PROG_ARRAY` with a given key and then jump into that function.



## `BPF_MAP_TYPE_PERF_EVENT_ARRAY`

With version 4.4 of the Linux kernel, released in January 2016, eBPF was integrated into the perf tooling system.
For those unfamiliar with it, perf is a tool in Linux that can be used for a wide swath of performance monitoring including CPU performance counters, tracepoints, kprobes, and uprobes (dynamic tracing).

The usage of `BPF_MAP_TYPE_PERF_EVENT_ARRAY` isn't super clear as there appear to be only two of examples of directly using it.
Both of these can be found in the following locations within the Linux kernel repository.

1. **`samples/bpf/tracex6_*.c`:** These two files ([`tracex6_kern.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/tracex6_kern.c) and [`tracex6_user.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/tracex6_user.c)) form a simplistic example. However, due to lack of comments or documentation, understanding its function isn't obvious.
The [commit message](https://github.com/torvalds/linux/commit/47efb30274cbec1bd3c0c980a7ece328df2c16a8) for the example's creation, done by Kaixu Xia, states the example "shows how to use the new ability to get the selected Hardware PMU counter value".

1. **`samples/bpf/trace_output_*.c`:** These two files ([`trace_output_kern.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/trace_output_kern.c) and [`trace_output_user.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/trace_output_user.c)) form the more complex example.
This one also lacks code documentation.
The [commit message](https://github.com/torvalds/linux/commit/39111695b1b88a21e81983a38786d877e770da81) for this example's creation, done by Alexei Starovoitov, states that a "kprobe is attached to sys_write() and trivial bpf program streams pid+cookie into userspace via PERF_COUNT_SW_BPF_OUTPUT event".


## `BPF_MAP_TYPE_PERCPU_HASH` and `BPF_MAP_TYPE_PERCPU_ARRAY`

With its release in May 2016, version 4.6 of the Linux kernel added the eBPF-map types `BPF_MAP_TYPE_PERCPU_HASH` and `BPF_MAP_TYPE_PERCPU_ARRAY`.
These two are nearly identical to [`BPF_MAP_TYPE_HASH`](#bpf-map-type-hash) and [`BPF_MAP_TYPE_ARRAY`](#bpf-map-type-array) except that one is created for each CPU core.
This allows for lock free uses of hash-tables and arrays in eBPF for high performance needs.
Though, of course, it must be an application where the divided results can be reconciled in the end.

There are a few, minor, technical details about the per-cpu eBPF-map types.
For those interested in the details of them check out the commits for each below:

* `BPF_MAP_TYPE_PERCPU_HASH`, initial commit [824bd0ce6c7c43a9e1e210abf124958e54d88342](https://github.com/torvalds/linux/commit/824bd0ce6c7c43a9e1e210abf124958e54d88342)
* `BPF_MAP_TYPE_PERCPU_ARRAY`, initial commit [a10423b87a7eae75da79ce80a8d9475047a674ee](https://github.com/torvalds/linux/commit/a10423b87a7eae75da79ce80a8d9475047a674ee)


## `BPF_MAP_TYPE_STACK_TRACE`

As it turns out, release 4.6 of the Linux kernel also included the eBPF-map type `BPF_MAP_TYPE_STACK_TRACE`.
As is obvious from the name, the `BPF_MAP_TYPE_STACK_TRACE` eBPF-map type is for storing stack-traces.
Unfortunately the use of it, like the per-cpu eBPF-map types that were also included in the same release, isn't well documented.

The `BPF_MAP_TYPE_STACK_TRACE` eBPF-map type was written by Alexei Starovoitov with it's original form being added with [commit `d5a3b1f691865be576c2bffa708549b8cdccda19`](https://github.com/torvalds/linux/commit/d5a3b1f691865be576c2bffa708549b8cdccda19).
The [commit message](https://github.com/torvalds/linux/commit/d5a3b1f691865be576c2bffa708549b8cdccda19) explains the eBPF-map type is to "store stack traces" and this commit also adds a "corresponding helper `bpf_get_stackid(ctx, map, flags)`" which is used to "walk user or kernel stack and return id".

For those looking to dig more into this, check out the code associated with `bpf_get_stackid` which, as of version 4.11 of Linux, is located on [line 115 of `kernel/bpf/stackmap.c`](https://github.com/torvalds/linux/blob/v4.11/kernel/bpf/stackmap.c#L115). 
One example of its usage can be seen in [`samples/bpf/trace_event_kern.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/trace_event_kern.c).
From this, it appears that `bpf_get_stackid` saves the stack-trace to the eBPF-map passed to it (of type `BPF_MAP_TYPE_STACK_TRACE`) and returns the id it can be fetched by.
The associated user side code for this example is located in [`samples/bpf/trace_event_user.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/trace_event_user.c).


## `BPF_MAP_TYPE_CGROUP_ARRAY`



Commit [4ed8ec521ed57c4e207ad464ca0388776de74d4b](https://github.com/torvalds/linux/commit/4ed8ec521ed57c4e207ad464ca0388776de74d4b)

Example [`samples/bpf/test_current_task_under_cgroup_kern.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/test_current_task_under_cgroup_kern.c)

## `BPF_MAP_TYPE_LRU_HASH` and `BPF_MAP_TYPE_LRU_PERCPU_HASH`

## `BPF_MAP_TYPE_LPM_TRIE`


--------------

As the article explains, eBPF programs are marked for their appropriate system by being designated a "eBPF program type".
While the `bpf` syscall is needed for all types of eBPF programs, from network frame filtering to hardware monitoring, it still requires some context from the user such as they type of eBPF program.
