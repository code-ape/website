+++
title = "eBPF, part 1: Past, Present, and Future [DRAFT]"
date = "2017-04-25"
tags = ["eBPF", "BPF", "Networking", "Linux"] 

summary = '''
TODO
'''
+++


# eBPF, part 1

This article is the first in a series on eBPF.
Each will build on the prior ones and progress from concepts and context towards examples and implementations.
This first article will explore eBPF's history, current state, and future trajectory.
In doing so I hope to make the current state and functions of eBPF more coherent.
As with many software projects, eBPF can appear odd and spastic without the context of the history which shaped it.


# Intro

The Extended Berkley Packet Filter, or eBPF for short, is difficult to explain and understand in its entirety.
This is partially due to how different it is from prior efforts to solve the problems eBPF solves.
Arguably, however, this biggest reason is its name.
When someone first learns of eBPF they likely don't know what BFP or what it means for it to be "extended".
The world "Berkely" also isn't helpful apart from hinting at its inception in Berkley, California, USA.
The only words in eBPF's name likely to have meaning to someone seeing it for the first time are "packet filtering".
This gives no indication of the myriad of things eBPF can be used for other than network filtering.
Though, the Linux community didn't realized how far eBPF would spread when it was named.

At its core eBPF is a highly efficient virtual machine that lives in the kernel.
Its original purpose, efficient network frame filtering, made this virtual machine, and thus eBPF, an ideal engine for processing events in general.
It is due to this that there are currently twelve different types of eBPF programs, as of writing, with many of them serving purposes unrelated to networking.

This article, "eBPF: Past, Present, and Future", will walk through the eBPF's history starting with BPF, the current state of eBPF, and what the future may hold for it.
In doing so it aims to allow a reader, who knows nothing about eBPF and has intermediate familiarity with Linux, to have a firm grasp on the concepts and uses eBPF along with providing a strong context for how it came to be what it is.


# Clarifications, Terms, and Corrections

This article attempts to be as factually correct as possible while still being approachable to someone who knows nothing about the topic of eBPF.
In setting such a lofty goal a few things are imminent.

1. **Clarifications**.
This article is intended to be readable for someone who knows nothing about eBPF and has intermediate familiarity with Linux.
However, having spent many hours researching for this article, I expect there are somethings which appear obvious to me but not to those unfamiliar with the topic.
This is not intentional but a result of spending over 30 hours with this content.
If something needs more explanation or clarification please submit an issue to the [Github repository for this website](https://github.com/code-ape/website) stating what needs more information.
1. **Terms.**
This article favors using technically correct terms over commonly used ones which are incorrect.
One example of this is that the Berkley Packet Filter, despite its name, filters network frames, not packets.
The subsection below, titled [Terms](#terms), lists all terms which may be misrepresented, for one reason or another, along with their explicit meaning in the scope of this article.
1. **Corrections.**
In writing this article I attempted to research, find, and cite as much evidence as possible for what is written here.
That being said, this is an attempt to represent history, a field where these is always both more to say and multiple perspectives on everything.
As such this article welcomes feedback and corrections with supporting evidence.
Feedback can be submitted with their respective evidence as issues to the [Github repository for this website](https://github.com/code-ape/website).

## Terms

* **BPF:** The Berkley Packet Filter found in FreeBSD.
* **Network Packet:** The Extended Berkley Packet Filter found in Linux.
* **Network Packet:** TODO
* **Network Frame:** TODO

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
By this, BPF gave a processor comparable to those found in new graphing calculators the ability to process a theoretical max of 2.6 Gbps of network traffic through a safe kernel virtual machine.[[^max_drop_rate]]
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
What eBPF offered, in short, was the an in kernel virtual machine, like BPF, but made more efficient, thanks to JIT compiling of the eBPF code, and with the ability to be used for general event processing.
With this ability for kernel developers to utilize the eBPF virtual machine else where in the kernel, eBPF's uses have rapidly grown since its inception to include a variety of other inner-kernel systems. These uses generally fall under network monitoring, network actions, or system monitoring.
Thus eBPF programs can be be used to switch network or track delays on disk reads.

The other major improvement eBPF brings is global data structures to the eBPF virtual machine.
This allowed state to persist between events and thus be aggregated for uses including statistics and context aware behavior.

Before diving into eBPF it's worth making a clarification.
The Linux community has a habit of referring to eBPF as simply "BPF".
Official documentation will usually reference eBPF as "eBPF" when speaking about it at a "high level", away from the code.
However, many implementation level naming conventions and pieces of documentation refer to it as "BPF".
To clear up any confusion before continuing, as of this article's writing Linux only has eBPF and thus any references to BPF are really references to eBPF.[[^bpf_in_linux]]
Some documentation related to Linux also uses "cBPF", short for "classic BPF", to refer to BPF and make the distinction between the two more clear.

[^bpf_in_linux]: There is one exception to this statement. On August 18th, 2003 the SCO Group (SCO) gave a presentation in Las Vegas which "alleged infringement by the Linux developers" [Perens]. SCO referred to specific pieces of code in Linux including an implementation of BPF [Perens]. As best I could find from documents on the matter, the code related to this alleged infringement was written by Jay Schulist who appears to have implemented a BPF virtual machine in the Linux kernel [Perens]. From my findings it appears Schulist's implementation did not take code from prior software but instead implemented it by following documentation on the virtual machine's specifications [Perens]. The accusation does not appear to have resulted in any action since SCO did not own the original BPF code [Perens]. Regardless, I was unable to find any references to the original BPF virtual machine existing in Linux outside those referring to this event. This could be due to the Linux kernel's frequent use of "BPF" to refer to eBPF which undoubtedly making finding any references to BPF, prior to eBPF's inception, much harder. At the very least, it appears that if BPF did exist in the Linux prior to eBPF it was not highly used or changed and thus would have simply been succeeded by eBPF. Source on SCO controversy with Linux comes from Bruce Perens: [http://web.archive.org/web/20030828144050/perens.com/Articles/SCO/SCOSlideShow.html](http://web.archive.org/web/20030828144050/perens.com/Articles/SCO/SCOSlideShow.html)

# Kernel-Space Programs and Smart NICs: The Future


# Further reading

There are plenty of resources out there related to BPF, however I have yet to find one that is approachable, coherent, and complete.
This is in part due to the rapid progress being done on it and in part due to the relatively scarce development efforts on it.

However, Quentin Monnet of 6WIND has put together the undisputed best compilation of resources related to eBPF that I have seen.
This compilation, which he countines to update, can be found [on his blog here](https://qmonnet.github.io/whirl-offload/2016/09/01/dive-into-bpf/).

The BCC project also maintains a convenient list of eBPF features including the kernel version they were released with and the commit that added them to the kernel. [Link here](https://github.com/iovisor/bcc/blob/master/docs/kernel-versions.md).


* http://wiki.linuxwall.info/doku.php/en:ressources:dossiers:networking:traffic_control
* http://tldp.org/HOWTO/Traffic-Control-HOWTO/index.html
* https://wiki.archlinux.org/index.php/Advanced_traffic_control
* http://lartc.org/howto/lartc.adv-filter.policing.html#AEN1393
* http://lartc.org/howto/lartc.netfilter.html
* http://man7.org/linux/man-pages/man8/tc-bpf.8.html

DPDK:

* https://blog.selectel.com/introduction-dpdk-architecture-principles/
* https://www.privateinternetaccess.com/blog/2016/01/linux-networking-stack-from-the-ground-up-part-1/
