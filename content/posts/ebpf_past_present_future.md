+++
title = "eBPF: Past, Present, and Future [DRAFT]"
date = "2017-04-19"
tags = ["eBPF", "BPF", "Networking", "Linux"] 

summary = '''
TODO
'''
+++



# eBPF, part 1 of 3

This article is the first in a three part series on eBPF.
Each will build on the prior ones and progress from concepts and explanations towards examples and implementations.
This will culminate in the last article which involves building a basic driver for eBPF in Rust.
This first article will explore the eBPF's history, current state, and future trajectory.
In doing so I hope to make the current state and functions of eBPF, along with its siblings, more coherent.
As with many software projects, eBPF can appear odd and spastic in form without the context of the history which shaped it.

# Intro

The difficulty of explaining and using eBPF stems from how different it is from anything the general methods of network operations.

It is a new, fundamentally different abstraction of networking.
It is built into the Linux kernel and subsequently approaches networking the way one might imagine a kernel developer would.


The path to modern day eBPF is not a simple one.
**TODO: add more here.**

# BPF and FreeBSD: The Past

To understand eBPF in Linux it is best to start with a different operating system, FreeBSD.
In 1993 the paper *"The BSD Packet Filter - A New Architecture for User-level Packet Capture, McCanne & Jacobson"* was presented at the 1993 Winter USENIX conference in San Diego, California, USA.
It was written by Steven McCanne and Van Jacobson who, at that time, were both working at the Lawrence Berkeley National Laboratory.
In the paper, McCanne and Jacobson describe the BSD Packet Filter, or BPF for short, including its placement in the kernel and implementation as a virtual machine.

What BPF did so differently than its predecessors, such as the CMU/Stanford Packet Filter (CSPF), was to use a well thought out memory model and then expose that through an efficient virtual machine inside the kernel.
By this, BPF filters can do traffic filtering in a highly efficient manner while still maintaining a boundary between the filter code and the kernel.

In their paper, McCanne and Jacobson's offer to following diagram to help visualize this.
Importantly, BPF employs a buffer between the filter and user-space to avoid having to make the expensive context switch between user-space and kernel-space for every packet the filter matches on.

![bpf_layout_diagram](/images/bpf_layout_diagram.png "BPF layout diagram from McCanne and Jacobson's paper.")

Perhaps the most important thing that McCanne and Jacobson did was to define the design of the virtual machine by the following five statement:

> 1. It must be protocol independent. The kernel should not have to be modified to add new protocol support.
2. It must be general. The instruction set should be rich enough to handle unforeseen uses.
3. Packet data references should be minimized.
4. Decoding an instruction should consist of a single C switch statement.
5. The abstract machine registers[[^abstract_machine]] should reside in physical registers.

[^abstract_machine]: "Abstract machine" in the phrase the paper uses to refer to BPF's virtual machine.

This emphasis on expandable generality and performance is likely the reason why eBPF, in its modern form, encompasses vastly more than the original implementation of BPF did.
Yet the BPF virtual machine was impressively simple and concise, it "consists of an accumulator, an index register, a scratch memory store, and an implicit program counter".[McCanne and Jacobson]
This can be seen by the register code below which matches all IP packets.
Explanations of each operation are to its right.

```
    ldh [12]                    // load ethertype field info into register
    jeq #ETHERTYPE_IP, L1, L2   // compare register to ethertype for IP
L1: ret #TRUE                   // if comparison is true, return true
L2: ret #0                      // if comparison is false, return 0
```

Using only 4 virtual machine instructions, BPF is able to offer a highly useful IP packet filter!
To make a point about just how efficient this design was, the original BPF implementation was able to reject a packet with a minimum of **only 184 CPU instructions**.
This is the instructions from the beginning to the end of the `bpf_tap` call meaning it measures both the work done by the BPF implementation plus the rejection filter.[[^instruction_count]]
By this, BPF gave a processor comparable to those found in new graphing calculators the ability to process a theoretical max of 2.6 Gbps of network traffic through a kernel safe virtual machine.[[^max_drop_rate]]
The efficiency of this can be emphasized by comparing it to context switching performance.
On a SPARCstation 2, the hardware used to do these measurements, doing a context switch could take anywhere between 2,840 instructions and 16,000+ instructions (equivalent 71 microseconds and 400+ microseconds), depending on the number of processes competing for resources and size of contexts being swapped.[[^sparcstation2_context_switching]]

[^instruction_count]: This number comes from the fact that a rejection took ~4.6 microseconds and the computer they were running it on, a SPARCstation 2, had a 40MHz processor. Result of: (4.6 usec)(40 MHz), [Wolfram Alpha calculation](https://www.wolframalpha.com/input/?i=4.6+usec+*+(40+MHz)).
[^max_drop_rate]: Result of: (1500 bytes / Hz)/(4.6 usec), [Wolfram Alpha calculation](https://www.wolframalpha.com/input/?i=(1500+bytes+%2F+Hz)(4.6+usec)%5E-1).
[^sparcstation2_context_switching]: Source [http://manpages.ubuntu.com/manpages/trusty/lat_ctx.8.html](http://manpages.ubuntu.com/manpages/trusty/lat_ctx.8.html)

Finally, it's worth noting two things in the closing part of McCanne and Jacobson's paper.
First, that BPF was approximately two years old when their paper was published.
This is noteworthy because it shows the development of BPF was a gradual one, something that continues with the technologies that succeeded it.
Second, it mentions tcpdump as the most widely used program which utilizes BPF at the time of writing.[[^tcpdump_author]]
This means tcpdump, one of the most widely used network debugging tools today, has used BPF technology for at least 24 years!
I mention this because many people don't realize how long the family of BPF technologies has been in use.
When this paper was published BPF wasn't a nifty idea with a alpha level implementation.
It had been tested and used for two years and already found its way into multiple tools.

[^tcpdump_author]: As a fun fact, Steven McCanne was also one of the original authors of tcpdump, along with Van Jacobson and Craig Leres, all of whom were working at the Lawrence Berkeley National Laboratory.

For those who are interested, McCanne and Jacobson's paper is only 11 pages and a worthwhile read. A scan of the original paper can be found [here](/pdfs/The BSD Packet Filter - A New Architecture for User-level Packet Capture, McCanne & Jacobson, scan.pdf) and a PDF rendering of the draft can be found [here](/pdfs/The BSD Packet Filter - A New Architecture for User-level Packet Capture, McCanne & Jacobson, draft.pdf).[[^ebpf_paper_scan]][[^ebpf_paper_draft]]
However, this article's goal is to explain eBPF and thus must continue on.

[^ebpf_paper_scan]: Cached from link on 2017-04-20, [https://www.usenix.org/legacy/publications/library/proceedings/sd93/mccanne.pdf](https://www.usenix.org/legacy/publications/library/proceedings/sd93/mccanne.pdf)
[^ebpf_paper_draft]: Cached from link on 2017-04-20, [http://www.tcpdump.org/papers/bpf-usenix93.pdf](http://www.tcpdump.org/papers/bpf-usenix93.pdf)

# eBPF and Linux: The Present

When Linux kernel version 3.18 was released in December 2014 it included the first implementation of extended BPF (eBPF).
What eBPF offered, in short, was the same efficient event processing as BPF but expanded beyond filtering packets to a variety of other events in the kernel.
Thus an eBPF filter can be be used to track many different types of events ranging from system calls to disk activity.
It also introduced global data structures to the kernel virtual machine.
This allowed state to persist between events and thus be aggregated for uses including statistics and context aware filter behavior.

Before diving into eBPF it's worth making a clarification.
The Linux community has a habit of referring to eBPF as simply "BPF".
Official documentation will usually reference eBPF as "eBPF" when speaking about it at a "high level", away from the code.
However, many implementation level naming conventions and pieces of documentation refer to it as "BPF".
To clear up any confusion before continuing, as of this article's writing Linux only has eBPF and thus any references to BPF are really references to eBPF.[[^bpf_in_linux]]
Some documentation related to Linux also uses "cBPF", short for "classis BPF", to refer to BPF and make the distinction between the two more clear.

[^bpf_in_linux]: There is one exception to this statement. On August 18th, 2003 the SCO Group (SCO) gave a presentation in Las Vegas which "alleged infringement by the Linux developers" [Perens]. SCO referred to specific pieces of code in Linux including an implementation of BPF [Perens]. As best I could find from documents on the matter, the code related to this alleged infringement was written by Jay Schulist who appears to have implemented a BPF virtual machine in the Linux kernel [Perens]. From my findings it appears Schulist's implementation did not take code from prior software but instead implemented it by following documentation on the virtual machine's specifications [Perens]. The accusation does not appear to have resulted in any action since SCO did not own the original BPF code [Perens]. Regardless, I was unable to find any references to the original BPF virtual machine existing in Linux outside those referring to this event. This could be due to the Linux kernel's frequent use of "BPF" to refer to eBPF which undoubtedly making finding any references to BPF, prior to eBPF's inception, much harder. At the very least, it appears that if BPF did exist in the Linux prior to eBPF it was not highly used or changed and thus would have simply been succeeded by eBPF. Source on SCO controversy with Linux comes from Bruce Perens: [http://web.archive.org/web/20030828144050/perens.com/Articles/SCO/SCOSlideShow.html](http://web.archive.org/web/20030828144050/perens.com/Articles/SCO/SCOSlideShow.html)

## Walking through the details of eBPF's implementation

A great summary of eBPF, when it was initially released, and its extensions over BPF can be found in the release notes for version 3.18 of the Linux kernel.[[^linux_3.18_notes]]

[^linux_3.18_notes]: Linux 3.18 release notes related to eBPF: [https://kernelnewbies.org/Linux_3.18#head-ead251efb6bbdbe2922e7c6bd0c7b46342e03dad](https://kernelnewbies.org/Linux_3.18#head-ead251efb6bbdbe2922e7c6bd0c7b46342e03dad)

> bpf() syscall is a multiplexor for a range of different operations on eBPF which can be characterized as "universal in-kernel virtual machine". eBPF is similar to original Berkeley Packet Filter used to filter network packets. eBPF "extends" classic BPF in multiple ways including ability to call in-kernel helper functions and access shared data structures like eBPF maps. The programs can be written in a restricted C that is compiled into eBPF bytecode and executed on the eBPF virtual machine or JITed into native instruction set.
>
>eBPF programs are similar to kernel modules. They are loaded by the user process and automatically unloaded when process exits. Each eBPF program is a safe run-to-completion set of instructions. eBPF verifier statically determines that the program terminates and is safe to execute. The programs are attached to different events. These events can be packets, tracepoint events and other types in the future. Beyond storing data the programs may call into in-kernel helper functions which may, for example, dump stack, do trace_printk or other forms of live kernel debugging. 

This is a relatively dense explanation of eBPF so it's worth walking through.
Since this explanation encapsulates most all of eBPF, getting a base level understanding of it will make understanding uses of eBPF relatively easy to follow.

### The Linux bpf syscall

The Linux `bpf` syscall, not to be confused with the FreeBSD syscall of the same name, does have [a man page](http://man7.org/linux/man-pages/man2/bpf.2.html).
Sadly, however, it's vastly out of date for the time being.
As of writing, building the most recent commit for the Linux man pages still has dated and missing information on the `bpf` syscall.
From the git logs it appears that the last notable contribution of new information to the man page was on **July 30, 2015**, over a year and eight months ago.[[^last_bpf_man_addition]]

[^last_bpf_man_addition]: This addition was done by Daniel Borkmann in commit `9a818dddcffce642126c4d8389ad679554617fc4` to the Linux [man-pages repository](https://git.kernel.org/pub/scm/docs/man-pages/man-pages.git/).

The information from the man page does provide a decent idea of the basic functionality of BPF.
The kernel code can be compared with this to gleam added features which haven't been documented yet.
For reference, this article will use the code of the most recent Linux kernel release, version 4.10.
As of 4.10 there are four files directly related to the operation of eBPF.
Each path listed below refers to a file in the kernel repository and links to the file it references.


* [`kernel/bpf/syscall.c`](https://github.com/torvalds/linux/blob/v4.10/kernel/bpf/syscall.c):
The Linux kernel code related to the `bpf` syscall.
* [`include/uapi/linux/bpf.h`](https://github.com/torvalds/linux/blob/v4.10/include/uapi/linux/bpf.h):
The `bpf` header file for assisting in using the `bpf` syscall.
* [`net/core/filter.c`](https://github.com/torvalds/linux/blob/v4.10/net/core/filter.c):
The eBPF kernel side code that runs the virtual machine.
* [`net/core/sock.c`](https://github.com/torvalds/linux/blob/v4.10/net/core/sock.c):
Includes the `setsockopt` code used to manipulate eBPF filters.


### eBPF commands

To begin with let's look at the ten commands for the `bpf` Linux syscall.
Of those ten, six are listed in the man page: `BPF_PROG_LOAD`, `BPF_MAP_CREATE`, `BPF_MAP_LOOKUP_ELEM`, `BPF_MAP_UPDATE_ELEM`, `BPF_MAP_DELETE_ELEM`, and `BPF_MAP_GET_NEXT_KEY`.
Of these commands there are really only two types of actions the Linux `bpf` syscall can do: loading an eBPF program and various manipulations of maps in the eBPF system.

A quick look at the `bpf_enum` in `include/uapi/linux/bpf.h` ([link here](https://github.com/torvalds/linux/blob/v4.10/include/uapi/linux/bpf.h#L67)) shows the four other commands: `BPF_OBJ_PIN`, `BPF_OBJ_GET`, `BPF_PROG_ATTACH`, `BPF_PROG_DETACH`.
All together this gives us the following 10 commands.

```c
// from https://github.com/torvalds/linux/blob/v4.10/include/uapi/linux/bpf.h#L67
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

These calls for the basics of what it possible 
To give some context to these, we'll quickly walk through the different commands for the `bpf` Linux syscall.

To begin with, `BPF_PROG_LOAD` is used for the loading of an eBPF program and is straightforward.
It requires the type of eBPF program (more on that in a [below]???), the array of eBPF virtual machine instructions, the license associated with the filter, a log buffer for messages from validating the filter code, and the log level for those messages.
To see an example of how this is done in C refer to the [man page](http://man7.org/linux/man-pages/man2/bpf.2.html) mentioned above.

Next, there are the five map operations.
Here we encounter another term which has been outgrown by its evolution.
As of writing eBPF has ten types of "maps", which will be expanded upon in the ??? section.
For the moment simply know that eBPF offers different data structures that are either hash maps or arrays.
A number of specialized variants of these exist for more specialized circumstances.
This article will use the term "eBPF-map" to refer to the all of these different data structures eBPF offers for storing state.

The eBPF-map operations are fairly self descriptive and are used to create eBPF-maps, lookup an element from them, update an element, delete an element, and iterate through an eBPF-map (`BPF_MAP_GET_NEXT_KEY`).
Creating a map only requires the type of eBPF-map desired, the size of the keys, the size of the values, and the maximum number of entries.

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

[^ebpf_pin_commit]: They were contributed by Daniel Borkmann and David S. Miller with commit [`	b2197755b2633e164a439682fb05a9b5ea48f706`](https://github.com/torvalds/linux/commit/b2197755b2633e164a439682fb05a9b5ea48f706).

[^linux_4.4_release_notes]: Linux kernel 4.4 release notes: [https://kernelnewbies.org/Linux_4.4#head-20c20e63018e8fb916fd26476eda2512e2d96632](https://kernelnewbies.org/Linux_4.4#head-20c20e63018e8fb916fd26476eda2512e2d96632)

Finally, we have the last two commands `BPF_PROG_ATTACH` and `BPF_PROG_DETACH`.
These commands were actually just added with version 4.10 of the Linux kernel in February of 2017,  only two months ago, though they appear to have been written in November of 2016.[[^ebpf_attach_detach_commit]]
The version 4.10 release notes explain that this is used for attaching eBPF programs to cgroups.[[^linux_4.10_release_notes]]
For those not familiar with cgroups, they're a Linux kernel feature used on processes for resource limiting and isolation.
The primary use case for eBPF with cgroups is that filters can be used to accept or drop traffic either to or from processes of a cgroup.

It is worth noting that the eBPF program type `BPF_PROG_TYPE_CGROUP_SOCK` also exists which appears to allow control over which device `AF_INET` and `AF_INET6` sockets are attached to for processes in the designated cgroup.
This is evidence of the possible future of eBPF programs in the Linux kernel, a future where eBPF program are used for injection of non-trivial logic by users into kernel functionality.


[^ebpf_attach_detach_commit]: This was contributed by Daniel Mack with David S. Miller on November 23, 2016 with commit [f4324551489e8781d838f941b7aee4208e52e8bf](https://github.com/torvalds/linux/commit/f4324551489e8781d838f941b7aee4208e52e8bf).
[^linux_4.10_release_notes]: Linux 4.10 release notes: [https://kernelnewbies.org/Linux_4.10](https://kernelnewbies.org/Linux_4.10)


### eBPF program types

There are currently 12 types of eBPF programs, which is a substantial number.
Of these twelve, four are listed on the man page and only one has any real documentation.
Also, before proceeding, it's helpful to clarify that the enumeration of all eBPF program types contains thirteen options because the first one is `BPF_PROG_TYPE_UNSPEC`.
This option for the program type is invalid to use and exists as the first option to ensure that a zero, in its many possible forms with C code, doesn't accidentally slip in for the program type.

```C
// From https://github.com/torvalds/linux/blob/v4.10/include/uapi/linux/bpf.h#L94

enum bpf_prog_type {
	BPF_PROG_TYPE_UNSPEC,
	BPF_PROG_TYPE_SOCKET_FILTER,
	BPF_PROG_TYPE_KPROBE,
	BPF_PROG_TYPE_SCHED_CLS,
	BPF_PROG_TYPE_SCHED_ACT,
	BPF_PROG_TYPE_TRACEPOINT,
	BPF_PROG_TYPE_XDP,
	BPF_PROG_TYPE_PERF_EVENT,
	BPF_PROG_TYPE_CGROUP_SKB,
	BPF_PROG_TYPE_CGROUP_SOCK,
	BPF_PROG_TYPE_LWT_IN,
	BPF_PROG_TYPE_LWT_OUT,
	BPF_PROG_TYPE_LWT_XMIT,
};
```

The first valid option, `BPF_PROG_TYPE_SOCKET_FILTER`, is the easiest to understand as it is used for programs that do what BPF was originally designed to do: filter packets for user-space processing.
These programs return either `-1`, to indicate the packet matches the filter, or `0`, to indicate the packet does not match the filter.
It is important to remember that there are use cases where a user isn't interested in the raw packets but aggregate information on them.
For such situations a `BPF_PROG_TYPE_SOCKET_FILTER` program can be used that always returns `0` but aggregates state into a eBPF-map which the user can retrieve at their discretion.

Next there is the `BPF_PROG_TYPE_KPROBE` eBPF program type.
Kprobes are another feature of the Linux kernel and were first introduced into version 2.6.11 of the kernel by IBM in March 2005.[[^original_kprobe_commit]]
At their core kprobes are somewhat technical, but in the end they allow for inspection of the kernel by tying a bit of custom instructions to a kernel instruction.
This allows for inspection of the kernels guts on anything from opening a socket to flushing a disk queue.

[^original_kprobe_commit]: The original commit appears to come from Ananth N Mavinakayanahalli of IBM and the message from it can be found in the kernel 2.6.11 change log: [https://www.kernel.org/pub/linux/kernel/v2.6/ChangeLog-2.6.11](https://www.kernel.org/pub/linux/kernel/v2.6/ChangeLog-2.6.11)

PICKUP_HERE

* `BPF_PROG_TYPE_UNSPEC`: Reserved as an invalid program type
* `BPF_PROG_TYPE_SOCKET_FILTER`: Declares the filter should receive packets from a socket.
* `BPF_PROG_TYPE_KPROBE`: Declares the filter should receive packets from a krpobe ([intro article on kprobes can be found here](https://lwn.net/Articles/132196/)).
* `BPF_PROG_TYPE_SCHED_CLS`: 
* `BPF_PROG_TYPE_SCHED_ACT`: 



### tc ???

# XDP and Smart NICs: The Future

While XDP is another topic I will cover in the future, it is also one worth at least touching on as it is strongly tied to eBPF.


# eBPF tool-chains

Currently there are a few tool chains to choose from.

These include

## Linux bindings

Because eBPF is part of the kernel it must be exposed by it.
However, since these are the low level user-space bindings to the kernel, they must be built up with lots of other code before they can serve any use.

*For those who are interested in seeing some examples of the low level usage of the kernel headers, check out Linus Torvalds' example directory [on Github](https://github.com/torvalds/linux/tree/master/samples/bpf).*


## BCC by IO Visor / Plumgrid

The first version of BCC were released in June of 2015 by the Plumgrid team before Plumgrid was acquired by VMWare in December 2016.[[^plumgrid_acquisition]]
It is now branded under IO Visor, fully known as the IO Visor Project, which is a Linux Foundation Collaborative Project and has VMWare as [one of its two platinum members](https://www.iovisor.org/members).


If you venture to [IO Visor's "About" page](https://www.iovisor.org/about) you'll notice that the technology is looks to develop is basically eBPF:

[^plumgrid_acquisition]: Source: [https://www.sdxcentral.com/articles/news/vmware-acquires-employees-assets-plumgrid/2016/12/](https://www.sdxcentral.com/articles/news/vmware-acquires-employees-assets-plumgrid/2016/12/)


> The IO Visor Project is an open source project and a community of developers to accelerate the innovation, development, and sharing of virtualized in-kernel IO services for tracing, analytics, monitoring, security and networking functions.


Indeed, as of writing this article the IO Visor lists three technologies: eBPF, XDP, and it's BCC tool-chain to use them.

The result is this is that BCC, an acronym for BPF Compiler Collection, allows uses to conveniently load C code of eBPF programs, insert them into the kernel, and the get data from them.

## bpftools by CloudFlare

# Projects using eBPF

There are a few projects currently making use of eBPF.

## Cilium

# Further reading

There are plenty of resources out there related to BPF, however I have yet to find one that is approachable, coherent, and complete.
This is in part due to the rapid progress being done on it and in part due to the relatively scarce development efforts on it.

However, Quentin Monnet of 6WIND has put together the undisputed best compilation of resources related to eBPF that I have seen.
This compilation, which he countines to update, can be found [on his blog here](https://qmonnet.github.io/whirl-offload/2016/09/01/dive-into-bpf/).




