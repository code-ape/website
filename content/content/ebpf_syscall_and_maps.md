+++
title = "eBPF, part 2: Syscall and Map Types"
date = "2017-05-11"
categories = ["Technical Writings"]
version = 1
version_history = "https://github.com/code-ape/website/commits/master/content/content/ebpf_syscall_and_maps.md"
tags = ["eBPF", "BPF", "Networking", "Linux", "Data Structures"] 

summary = '''
Due to the its fast adoption, using eBPF is different for each system it has been integrated with.
However, the common denominator for all uses is the syscall for eBPF.
This syscall, the `bpf` syscall in Linux, allows eBPF programs to be loaded into the kernel and eBPF-maps to be created and manipulated.
As the second installment in the eBPF series, this article works through all the commands of the syscall plus the different eBPF-map types, since they are controlled through the syscall.
'''
+++


# eBPF, part 2

This article is the second in a series on eBPF.
It builds upon the previous article, ["eBPF, part 1: Past, Present, and Future"]({{< ref "ebpf_past_present_future.md" >}}), by diving into the core of using eBPF: the Linux `bpf` syscall.
In doing so this article hopes to offer a completely fleshed out depiction of the core machinery one must use for utilizing eBPF.

*This article also references future articles that will be written for this series. For those who may cite this article, it will be updated to reference said articles when they are posted. However, previous versions of this article will be accessible for reference and links to them will be posted on this page.*


# Intro

In the previous article, ["eBPF, part 1: Past, Present, and Future"]({{< ref "ebpf_past_present_future.md" >}}), the process of using an eBPF program was summarized into three steps.

1. Creation of the eBPF program as byte code.
2. Loading the program into the kernel and creating necessary eBPF-maps.
3. Attaching the loaded program to a system.

Due to the many different applications of eBPF, the details of step 1, creating the eBPF program, and step 3, attaching it to a system in the kernel, vary by use case.
However the core of eBPF, and thus what all applications of it have in common, is step two.
No matter the use case, an eBPF program must be loaded into the kernel and eBPF-maps, if used, must be configured for it.
This is all done by the Linux `bpf` syscall.


# Clarifications, Terms, and Corrections

This article maintains the same stance on clarifications, terms, and corrections as the first in its series.
Thus, for concision, this article will not repeat it.
For those looking to for more information on such matters please refer to 
section titled ["Clarifications, Terms, and Corrections" from the first article]({{< ref "ebpf_past_present_future.md#clarifications-terms-and-corrections" >}}).


## Terms

This article builds on the terms from the subsection titled ["Terms" from the first article in this series]({{< ref "ebpf_past_present_future.md#terms" >}}).
For those looking for clarification on terms not defined below, please check with the section from the original article.
If you feel that a term is missing then please request a clarification as outlined in the ["Clarifications, Terms, and Corrections" from the first article]({{< ref "ebpf_past_present_future.md#clarifications-terms-and-corrections" >}}).

* **Syscall:** Common shorthand for "system call". It refers to the programmatic interface that user programs use to make requests to the operating system. This article prefers to use "syscall" over "system call" due to it being the more standard term in current writing.
* **Linux `bpf` syscall:** The syscall found in the Linux operating system for using eBPF.
* **Man page:** Common shorthand for "manual page". It refers to the documentation pages common on Unix and Unix-like systems. This article prefers to use "man page" over "manual page" due to it being the more standard term in current writing.


# The Linux bpf syscall

When eBPF was first added to the Linux kernel, with version 3.18, what was technically added was the `bpf` syscall along with the underlying machinery in the kernel.
The [release notes on the Linux `bpf` syscall](https://kernelnewbies.org/Linux_3.18#head-ead251efb6bbdbe2922e7c6bd0c7b46342e03dad) capture eBPF and its technical implementation quite well.
For those not interested in reading through them, the parts of the release notes which are relevant for this particular article are as follows.
Note that some details of this have changed since eBPF's initial release.

> bpf() syscall is a multiplexor for a range of different operations on eBPF
...
eBPF "extends" classic BPF in multiple ways including ability to call in-kernel helper functions and access shared data structures like eBPF maps.
...
[eBPF programs] are loaded by the user process and automatically unloaded when process exits [this is no longer always true].
Each eBPF program is a safe run-to-completion set of instructions.
eBPF verifier statically determines that the program terminates and is safe to execute.
... programs may call into in-kernel helper functions which may, for example, dump stack, do trace_printk or other forms of live kernel debugging.


In diving into this syscall one would expect to look where documentation for Linux syscalls usually resides: in a section 2 man page.[[^section_2_man_page]]
This syscall, as with most Linux syscalls, does have [a man page](http://man7.org/linux/man-pages/man2/bpf.2.html).
Sadly, however, some aspects of it are vastly out of date as of this writing.
In fact, from the git logs for the [Linux man pages](https://git.kernel.org/pub/scm/docs/man-pages/man-pages.git) it appears that the last notable contribution of new information to the man page was on **July 30, 2015**, over a year and nine months ago.[[^last_bpf_man_addition]]
Thankfully, however, the majority of the outdated information is related to the types of eBPF programs and eBPF-maps that exist.
These missing details do, of course, exist in the Linux kernel code and thus this article makes references to the kernel code at times since it is the source of truth for eBPF's implementation.
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
Of these documented commands, there are really only two types: loading an eBPF program and various manipulations of eBPF-maps.
The eBPF-map operations are fairly self descriptive and are used to create eBPF-maps, lookup an element from them, update an element, delete an element, and iterate through an eBPF-map (by using `BPF_MAP_GET_NEXT_KEY`).

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

*These calls form the basis of what is possible for a user to do with the eBPF system by itself. Of course, this isn't super useful without the context of the other systems eBPF can be used with.
The third article in this series will be devoted to that topic, the systems eBPF can be used with, and this article will be updated to reference it when it is published.*


## `BPF_PROG_LOAD`

To begin with, the `BPF_PROG_LOAD` command is used for the loading an eBPF program into the Linux kernel and is straightforward to use.
It requires the type of eBPF program, the array of eBPF virtual machine instructions, the license associated with the filter, a log buffer for messages from validating the filter code, and the log level for those messages.
There are, as of this writing, twelve different types of eBPF programs.
These types correspond to different uses of eBPF and, as stated above, will be covered by the third article in this series.

The man page for the Linux `bpf` syscall does offer an [example of a function in C](http://man7.org/linux/man-pages/man2/bpf.2.html) which does this.

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
This article will use the term "eBPF-map" to refer to the all of these different data structures that eBPF offers for storing state.

Creating a map only requires the type of eBPF-map desired, the size of a key, the size of a value, the maximum number of entries, and whether or not to pre-allocate the map in memory.

Again, the Linux `bpf` syscall man page does offer an [example of a function in C](http://man7.org/linux/man-pages/man2/bpf.2.html) which does this.
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
However this still leaves a multiple of ~4,300 between the largest example I could find of an eBPF-map and the theoretical max.
For reference, use of super high capacity eBPF-maps should be used carefully  due to memory consumption.
The memory foot print for 2^32 pairs of 64 bit keys and 64 bit values comes out to 64GiB![[^max_ebpf_memory]]

[^max_ebpf_memory]: This comes from (2^32)*(64 bits + 64 bits), Wolfram Alpha calculation: [https://www.wolframalpha.com/input/?i=(2%5E32)(64+bits+%2B+64+bits)+to+GiB](https://www.wolframalpha.com/input/?i=(2%5E32)(64+bits+%2B+64+bits)+to+GiB)

The size of an eBPF-map also relates to the `map_flags` option.
This flag appears to have been added in version 4.6 of the Linux kernel which was released in May 2016.
This flag allows for users to decide whether or not to pre-allocate the eBPF-map.
Reading through the commit that added this, [6c90598174322b8888029e40dd84a4eb01f56afe](https://github.com/torvalds/linux/commit/6c90598174322b8888029e40dd84a4eb01f56afe), shows that this was needed for when using eBPF with kprobes.
However, there may be other times when this is needed or desired, such as to always run with the eBPF-map fully allocated in memory to avoid having to worry about exhausting available memory.

## `BPF_MAP_LOOKUP_ELEM`, `BPF_MAP_UPDATE_ELEM`, and `BPF_MAP_DELETE_ELEM`

As their names indicate, these eBPF commands are used for getting, setting, and deleting entries in eBPF-maps.
These all involve constructing the same C struct from `bpf_attr` union, though this has a union inside itself which will always be the `value` option in these cases.

Overall, these commands are extremely straightforward.
The return codes are documented on the [`bpf` syscall man page](http://man7.org/linux/man-pages/man2/bpf.2.html).
Here is an example function from the man page for functions that lookup and delete elements.

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
As you can see from the comments in the code block below, this command really is three: set value if no prior value exists, set value only if prior value exists, or set value regardless of if prior value exists.


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

As with most all data structures, iterating through the elements of a eBPF-hash table is an essential aspect of using them.
However, because hash-tables aren't ordered, some form of a helper function is needed to provide a deterministic linear iteration over all the elements in a hash-table.
To give an example, in Python there is the `iter` function which can transform a hash-table (known in Python as a dictionary) into something that can be processed in an ordered fashion.

For eBPF-maps iteration is achieved with the `BPF_MAP_GET_NEXT_KEY` command for the Linux `bpf` syscall. The syscall takes a pointer to a given key and a pointer for where to save the next key.
The behavior of the command isn't extremely intuitive, as the following cases exist for what will happen, according to the man page.

1. **Given key is found and it isn't the last in the iteration.**
The operation returns zero and sets the `next_key` pointer to the key of the next element. 
1. **Given key is not found.**
The operation returns zero and sets the `next_key` pointer to the key of the first element for the iteration.
1. **Given key is found and is the last in the iteration.**
A value of -1 is returned and errno is set to ENOENT. 
1. The man page also states *"other possible errno values are ENOMEM, EFAULT, EPERM, and EINVAL"* but offers no further explanation.

```C
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

This brings us to the first two of the four currently undocumented commands: `BPF_OBJ_PIN` and `BPF_OBJ_GET`.
Tracing through the history in the repository, one can find that `BPF_OBJ_PIN` and `BPF_OBJ_GET` were added in  version 4.4 of the Linux kernel.[[^ebpf_pin_commit]]
The release notes for version 4.4 state that two eBPF features were added: "unprivileged eBPF" and "persistent eBPF programs".[[^linux_4.4_release_notes]]
The `BPF_OBJ_PIN` command relates to the persistent eBPF programs feature of version 4.4 of the Linux kernel.
With this the Linux kernel features a new minimum file system located at `/sys/fs/bpf` which can hold eBPF-maps or eBPF programs.

This is useful because, prior to this, all eBPF-maps and eBPF programs were tied to the program that created them.
Thus it wasn't possible to have a tool create an eBPF program and exit because that would cause the filter to be destroyed.
This addition allows for eBPF-maps and eBPF programs to persist after the program that creates them exits.
Because a file system is used for this, eBPF-maps and eBPF programs are pinned to a path in the file system.
This command thus only needs the file descriptor of what to pin and the path to pin it at.

[^ebpf_pin_commit]: They were contributed by Daniel Borkmann and David S. Miller with commit [` b2197755b2633e164a439682fb05a9b5ea48f706`](https://github.com/torvalds/linux/commit/b2197755b2633e164a439682fb05a9b5ea48f706).

[^linux_4.4_release_notes]: Linux kernel 4.4 release notes: [https://kernelnewbies.org/Linux_4.4#head-20c20e63018e8fb916fd26476eda2512e2d96632](https://kernelnewbies.org/Linux_4.4#head-20c20e63018e8fb916fd26476eda2512e2d96632)

## `BPF_PROG_ATTACH` and `BPF_PROG_DETACH`

Finally, we have the last two, currently undocumented, commands `BPF_PROG_ATTACH` and `BPF_PROG_DETACH`.
These commands were actually just added with version 4.10 of the Linux kernel in February of 2017, only three months ago as of this writing, though they appear to have been written in November of 2016.[[^ebpf_attach_detach_commit]]
The release notes for version 4.10 explain that this is used for attaching eBPF programs to cgroups.[[^linux_4.10_release_notes]]
For those not familiar with them, cgroups are a Linux kernel feature used on processes for resource limiting and isolation.
The primary use case for eBPF with cgroups is that filters can be used to accept or drop traffic either to or from processes of a cgroup.
It is worth noting that the eBPF program type `BPF_PROG_TYPE_CGROUP_SOCK` also exists which appears to allow control over which device `AF_INET` and `AF_INET6` sockets are attached to for processes in the designated cgroup.

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


## `BPF_MAP_TYPE_HASH` and `BPF_MAP_TYPE_ARRAY`

The eBPF-map hash-table, represented by the value `BPF_MAP_TYPE_HASH` in the `bpf_map_type` C enum, was one of the first two map types to be added.
It made its debut only one minor release after eBPF with version 3.19 of the Linux kernel.[[^ebpf_map_hash_commit]]
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

The other eBPF-map type to be added with release 3.19 of the Linux kernel was `BPF_MAP_TYPE_ARRAY`.
This function like the hash-table type above except it indexes the entries like an array, meaning for a map with `n` elements you can only use indexes `0` to `n-1`. 

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
The man page states that, as of this writing, both the key and value must be 4 bytes in size.
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

The `BPF_MAP_TYPE_STACK_TRACE` eBPF-map type was written by Alexei Starovoitov with its original form being added with [commit `d5a3b1f691865be576c2bffa708549b8cdccda19`](https://github.com/torvalds/linux/commit/d5a3b1f691865be576c2bffa708549b8cdccda19).
The [commit message](https://github.com/torvalds/linux/commit/d5a3b1f691865be576c2bffa708549b8cdccda19) explains the eBPF-map type is to "store stack traces" and this commit also adds a "corresponding helper `bpf_get_stackid(ctx, map, flags)`" which is used to "walk user or kernel stack and return id".

For those looking to dig more into this, check out the code associated with `bpf_get_stackid` which, as of version 4.11 of Linux, is located on [line 115 of `kernel/bpf/stackmap.c`](https://github.com/torvalds/linux/blob/v4.11/kernel/bpf/stackmap.c#L115). 
One example of its usage can be seen in [`samples/bpf/trace_event_kern.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/trace_event_kern.c).
From this, it appears that `bpf_get_stackid` saves the stack-trace to the eBPF-map passed to it (of type `BPF_MAP_TYPE_STACK_TRACE`) and returns the id it can be fetched by.
The associated user side code for this example is located in [`samples/bpf/trace_event_user.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/trace_event_user.c).


## `BPF_MAP_TYPE_CGROUP_ARRAY`

The eBPF-map type `BPF_MAP_TYPE_CGROUP_ARRAY` was added to the Linux kernel with version 4.8 in October 2016.
It has a very niche usage which the release notes state is to "implement a bpf-way to check the cgroup2 membership of a skb" with reference to the following commits at the bottom of this section, all from Martin KaFai Lau on June 30, 2016.
The message of commit `4a482f34afcc162d8456f449b137ec2a95be60d8` offers the most clarity toward the `BPF_MAP_TYPE_CGROUP_ARRAY` type stating:

*"Adds a bpf helper, bpf_skb_in_cgroup, to decide if a skb->sk
belongs to a descendant of a cgroup2.
...
The user is expected to populate a BPF_MAP_TYPE_CGROUP_ARRAY
which will be used by the bpf_skb_in_cgroup."*

This can be seen in the example Lau provides in [`samples/bpf/test_current_task_under_cgroup_kern.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/test_current_task_under_cgroup_kern.c) with commit `a3f74617340b598dbc7eb5b68d4ed53b4a70f5eb` which contains the following code:

```C
struct bpf_elf_map SEC("maps") test_cgrp2_array_pin = {
   .type       = BPF_MAP_TYPE_CGROUP_ARRAY,
   .size_key   = sizeof(uint32_t),
   .size_value = sizeof(uint32_t),
   .pinning    = PIN_GLOBAL_NS,
   .max_elem   = 1,
};

...

    } else if (bpf_skb_in_cgroup(skb, &test_cgrp2_array_pin, 0) != 1) {

... 
```

This code checks that the the socket of the `skb`, which is a Linux socket buffer for the frame being processed, belongs to a descendant of any of the cgroup contained in the `test_cgrp2_array_pin` eBPF-map which is of type `BPF_MAP_TYPE_CGROUP_ARRAY`.
This function, as documented in the code, returns `1` if the `skb`'s socket does belong to a cgroup in the eBPF-map.


**Initial commits related to `BPF_MAP_TYPE_CGROUP_ARRAY`:**

* Commit [`1f3fe7ebf6136c341012db9f554d4caa566fcbaa`](https://github.com/torvalds/linux/commit/1f3fe7ebf6136c341012db9f554d4caa566fcbaa)
* Commit [`4ed8ec521ed57c4e207ad464ca0388776de74d4b`](https://github.com/torvalds/linux/commit/4ed8ec521ed57c4e207ad464ca0388776de74d4b)
* Commit [`4a482f34afcc162d8456f449b137ec2a95be60d8`](https://github.com/torvalds/linux/commit/4a482f34afcc162d8456f449b137ec2a95be60d8)
* Commit [`a3f74617340b598dbc7eb5b68d4ed53b4a70f5eb`](https://github.com/torvalds/linux/commit/a3f74617340b598dbc7eb5b68d4ed53b4a70f5eb)



## `BPF_MAP_TYPE_LRU_HASH` and `BPF_MAP_TYPE_LRU_PERCPU_HASH`

Sometimes it is desirable to keep track of only the most used items, the leaders or outliers of a set, due to memory limits or even lack of caring about the other values.
In the world of [cache replacement policies](https://en.wikipedia.org/wiki/Cache_replacement_policies), such a pattern is known as [Least Recently Used](https://en.wikipedia.org/wiki/Cache_replacement_policies#Least_Recently_Used_.28LRU.29), or LRU.
Based on this, and the information on the hash-table type of eBPF-maps from above, the functionality of the `BPF_MAP_TYPE_LRU_HASH` type of eBPF-maps is easy to guess.
It provide the ability to have a eBPF-map hash-table which is smaller than the total elements that will be added to it because, when it runs out of space, it purges elements which haven't recently been used.

However, the `BPF_MAP_TYPE_LRU_PERCPU_HASH` type's name can be misleading.
This type isn't like `BPF_MAP_TYPE_PERCPU_HASH` where each CPU core gets its own hash-table.
Instead, all cores share one hash-table but have they own LRU structures of the table.
This means, as best I can tell from the sparse code notes, that this eBPF-map type keeps entries which are highly used by a specific CPU core.
However, there's no documentation on the details of this and thus I am not sure exactly how purging of entities is determined.
This is likely due to how new these two types are.
They were just added with version 4.11 of the Linux kernel which was only released at the end of April 2017.

For those looking for more information on the `BPF_MAP_TYPE_LRU_HASH` and `BPF_MAP_TYPE_LRU_PERCPU_HASH` eBPF-map types, both were written by Martin KaFai Lau with commits [29ba732acbeece1e34c68483d1ec1f3720fa1bb3](https://github.com/torvalds/linux/commit/29ba732acbeece1e34c68483d1ec1f3720fa1bb3) and [8f8449384ec364ba2a654f11f94e754e4ff719e0](https://github.com/torvalds/linux/commit/8f8449384ec364ba2a654f11f94e754e4ff719e0).
There are also three files in the `samples/bpf/` directory of the Linux repository which makes use of `BPF_MAP_TYPE_LRU_HASH`: [map_perf_test_kern.c](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/map_perf_test_kern.c), [test_lru_dist.c](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/test_lru_dist.c), and [map_perf_test_user.c](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/map_perf_test_user.c). However, as of this writing, there are no samples using `BPF_MAP_TYPE_LRU_PERCPU_HASH`.


## `BPF_MAP_TYPE_LPM_TRIE`

The `BPF_MAP_TYPE_LPM_TRIE` is, perhaps, the most specialized of the eBPF-map types that are designed to store data.
For those not intimately versed in the world of non-standard data structures, including myself, a LPM trie is a [trie](https://en.wikipedia.org/wiki/Trie) used to select a specific option from a set of options based on which has the [Longest Prefix Match (LPM)](https://en.wikipedia.org/wiki/Longest_prefix_match).
Thus the option which is selected has the longest match relative to the value when starting at the beginning of both the option and the value.

A concrete example of this can be found on the [Wikipedia page for the topic](https://en.wikipedia.org/wiki/Longest_prefix_match) which explains that the IPv4 address `192.168.20.19` will match, when using LPM, the subnet `192.168.20.16/28` over the subnet `192.168.0.0/16` because the address matches the first three halves of the `192.168.20.16/28` subnet and only the first half of the `192.168.0.0/16` subnet.
Thus this algorithm matches narrower ranges over larger ones even when the value being matched exists in both.

As alluded to by the example, one application of LPM tries is with forwarding tables of some network protocols where data traveling through the network must be deterministically sent to one of multiple options the data is a valid match for.
However, this can be used for anything where prefix matching is used and, as of this writing, supports matching prefixes between 1 and 256 bytes in length (8 to 4096 bits).

For more information on the implementation of `BPF_MAP_TYPE_LPM_TRIE` check out commit [b95a5c4db09bc7c253636cb84dc9b12c577fd5a0](https://github.com/torvalds/linux/commit/b95a5c4db09bc7c253636cb84dc9b12c577fd5a0) of the Linux kernel repository which was authored by Daniel Mack.
As of version 4.11 of the Linux kernel there's only one example of using the LPM trie type of eBPF-map.
It's located on [line 60 of `samples/bpf/map_perf_test_kern.c`](https://github.com/torvalds/linux/blob/v4.11/samples/bpf/map_perf_test_kern.c#L60).


--------------

That concludes this article on the Linux `bpf` syscall and eBPF-map types!
In the next week the third installment of this series should be released on the types of eBPF programs there are.

