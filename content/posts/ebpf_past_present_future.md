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


# A brief history

The path to modern day eBPF is not a simple one.
**TODO: add more here.**

## BPF: the past

To understand eBPF in Linux it is best to start with a different operating system, FreeBSD.
In 1993 the paper *"The BSD Packet Filter - A New Architecture for User-level Packet Capture, McCanne & Jacobson"* was presented at the 1993 Winter USENIX conference in San Diego, California, USA.
It was written by Steven McCanne and Van Jacobson who, at that time, were both working at the Lawrence Berkeley National Laboratory.
In the paper, McCanne and Jacobson describe the BSD Packet Filter, or BPF for short, including its placement in the kernel and implementation as a virtual machine.

What BPF did so differently than its predecessors, such as CMU/Stanford Packet Filter (CSPF), was to use a well thought out memory model and then expose that through an efficient virtual machine inside the kernel.
By this, BPF filters can do traffic filtering as efficiently as possible while still maintaining a boundary between the filter code and the kernel.

To make a point about just how efficient this was, the original BPF filter was able to drop a packet with **only 184 CPU instructions**.
This number comes from the fact that a drop took ~4.6 microseconds and the computer they were running it on, a SPARCstation 2, had a 40MHz processor.[[^instruction_count]]
By this, BPF gave a processor comparable to those found in new graphing calculators the ability to drop a theoretical max of 2.6 Gbps of network traffic.[[^max_drop_rate]]
The efficiency of this can be emphasized by comparing it to context switching performance.
On a SPARCstation 2 doing a context switch, needed to go between kernel space and user space, could take anywhere between 71 microseconds and 400+ microseconds, depending on the number of processes competing for resources.[[^sparcstation2_context_switching]]

[^instruction_count]: Result of: (4.6 usec)(40 MHz), [Wolfram Alpha calculation](https://www.wolframalpha.com/input/?i=4.6+usec+*+(40+MHz)).
[^max_drop_rate]: Result of: (1500 bytes / Hz)/(4.6 usec), [Wolfram Alpha calculation](https://www.wolframalpha.com/input/?i=(1500+bytes+%2F+Hz)(4.6+usec)%5E-1).
[^sparcstation2_context_switching]: Source [http://manpages.ubuntu.com/manpages/trusty/lat_ctx.8.html](http://manpages.ubuntu.com/manpages/trusty/lat_ctx.8.html)

Perhaps the most important thing that McCanne and Jacobson did was to define the design of the virtual machine by the following five statement:

> 1. It must be protocol independent. The kernel should not have to be modified to add new protocol support.
2. It must be general. The instruction set should be rich enough to handle unforeseen uses.
3. Packet data references should be minimized.
4. Decoding an instruction should consist of a single C switch statement.
5. The abstract machine registers[[^abstract_machine]] should reside in physical registers.

[^abstract_machine]: "Abstract machine" in the phrase the paper uses to refer to BPF's virtual machine.

This emphasis on expandable generality and performance is likely the reason why eBPF, in its modern form, encompasses vastly more than the original implementation of BPF did.

*For those who are interested, McCanne and Jacobson's paper is only 11 pages and a worthwhile read. A scan of the original paper can be found [here](/pdfs/The BSD Packet Filter - A New Architecture for User-level Packet Capture, McCanne & Jacobson, scan.pdf) and a PDF rendering of the draft can be found [here](/pdfs/The BSD Packet Filter - A New Architecture for User-level Packet Capture, McCanne & Jacobson, draft.pdf).*[[^ebpf_paper_scan]][[^ebpf_paper_draft]]

[^ebpf_paper_scan]: Cached from link on 2017-04-20, [https://www.usenix.org/legacy/publications/library/proceedings/sd93/mccanne.pdf](https://www.usenix.org/legacy/publications/library/proceedings/sd93/mccanne.pdf)
[^ebpf_paper_draft]: Cached from link on 2017-04-20, [http://www.tcpdump.org/papers/bpf-usenix93.pdf](http://www.tcpdump.org/papers/bpf-usenix93.pdf)

## eBPF and Linux: the present

When Linux kernel version 3.18 was released in December 2014 it included the first implementation of eBPF.
I'd attempt to explain how eBPF is different than BPF, and in what ways, but instead I'll just post the release notes as they do an excellent job covering this.[[^linux_3.18_notes]]

[^linux_3.18_notes]: Linux 3.18 release notes related to eBPF: [https://kernelnewbies.org/Linux_3.18#head-ead251efb6bbdbe2922e7c6bd0c7b46342e03dad](https://kernelnewbies.org/Linux_3.18#head-ead251efb6bbdbe2922e7c6bd0c7b46342e03dad)

> bpf() syscall is a multiplexor for a range of different operations on eBPF which can be characterized as "universal in-kernel virtual machine". eBPF is similar to original Berkeley Packet Filter used to filter network packets. eBPF "extends" classic BPF in multiple ways including ability to call in-kernel helper functions and access shared data structures like eBPF maps. The programs can be written in a restricted C that is compiled into eBPF bytecode and executed on the eBPF virtual machine or JITed into native instruction set.
>
>eBPF programs are similar to kernel modules. They are loaded by the user process and automatically unloaded when process exits. Each eBPF program is a safe run-to-completion set of instructions. eBPF verifier statically determines that the program terminates and is safe to execute. The programs are attached to different events. These events can be packets, tracepoint events and other types in the future. Beyond storing data the programs may call into in-kernel helper functions which may, for example, dump stack, do trace_printk or other forms of live kernel debugging. 



With this new functionality

## XDP: the future

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




