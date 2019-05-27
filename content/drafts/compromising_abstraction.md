+++
title = "Compromising Abstraction [DRAFT]"
date = "2017-04-19"
categories = ["Technical Writings"]
tags = ["abstraction", "philosophy", "design"] 
draft = true

summary = '''
TODO
'''
+++

# Abstractions

Abstractions are useful because they are reductive; because they present a lossy representation of something which is easier to grasp.
And by this abstractions are both highly useful and dangerously seductive.
Abstractions tell us attractive tales of the realities they overlay. However, they don't convey that their representations are false or lossy in any way.
Zach Tellman captures this well with the statement: "No model, which is simplified, acknowledges that there is something outside of itself."

*For those of you who find this idea fascinating, I highly recommend Tellman's talk* **States and Nomads: Handling Software Complexity** *which can be [viewed on YouTube](https://www.youtube.com/watch?v=KGaFcI2UNrI).*


For software engineers such abstractions and models are everywhere.
The Linux kernel alone is a quarter century of human effort to offer accessibility and utility for the complexities of modern computer hardware.[[^accessible Linux kernel]]
Sometimes there are reminders that the interfaces we use are abstractions and that underneath them is something more nuanced.
Efficient socket polling is one such reminder.
Many common operating systems present the simple operation of socket polling while having their own unique solution for more performant needs.
Linux has [epoll](https://linux.die.net/man/4/epoll), FreeBSD has [kqueue](https://www.freebsd.org/cgi/man.cgi?kqueue), and Microsoft Windows has [I/O Completion Ports](https://msdn.microsoft.com/en-us/library/windows/desktop/aa365198(v=vs.85).aspx).
All of these make the programmer confront the underlying asynchronous nature of networking that the simpler polling model abstracts away.

[^accessible Linux kernel]: Relative, of course, to the complexity of what it overlays.


# Heirarchies

Perhaps one of the biggest lies abstractions tells us is that of the hierarchy.
By modeling abstractions with hierarchies we're told that between reality and any particular abstraction there's only one path.
But the world, and thus even abstractions, are really graphs and thus there are many ways to achieve something.

![graph hierarchy](/images/graph_hierarchy.png "Logo Title Text 1")


When a new abstraction confirms this graph structure it can be a jarring experience for some people.


