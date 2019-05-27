+++
title = "The Innovator's Dilemma and the future of data center storage"
date = "2019-03-23"
categories = ["Technical Writings"]
version = 1
version_history = "https://github.com/code-ape/website/commits/gh-pages/posts/hdd_are_facing_the_innovators_dilemma/index.html"
tags = ["Innovation", "Innovator's Dilemma", "Data Centers"] 

draft = true

summary = '''
TODO
'''
+++

*This article is written in present tense and first person to provide a more engaging narrative to the reader. However, all statements and claims are made with the time reference to when this was published. Thus "today" is March 23, 2019.*

# Intro

In 1997 Clayton Christensen's book "The Innovator's Dilemma" was published.
In it Christensen examines the mechanisms for how established and successful organizations can be seriously challenged by small unproven ones.
The gist of this mechanism is captured by his concept of the "Innovator's Dilemma" which has two parts: (1) the investment to return graph for innovation is an "s-curve" meaning significant investment is required before innovation pays off and (2) new small organizations have the freedom to innovate while large established organizations do not because they must maintain large sales volumes to sustain themselves.
Hard drive disks (HDDs) have long been the "established and successful" paradigm of data center data storage design for many decades.
Solid state drives (SSDs) have been steadily taking market share from them for roughly a decade now.
This leads to the question of "What does this mean for the future of data center storage?"


# Hot and cold data

In the world of storage you can lump most data onto a spectrum of "access frequency".
Data that's frequently accessed is hot.
Data that's rarely accessed is cold.
Today the standard paradigm is hot data goes on SSDs and cold data goes on HDDs.


# Economics

Let's take a look at some rough order of magnitude numbers to understand why.
Note that there are very rough ranges for current options in 2019.
While there are outliers that break out of these boundaries, this encaptures the vast majority of the options when selecting storage today.

|                             | HDD           | SSD             | SSD NVMe         |
|-----------------------------|---------------|-----------------|------------------|
| Seqential Throughput (MB/s) | ~100-200      | ~250-1,500      | ~1,000-4,000     |
| Latency (μs)                | ~2,000-20,000 | ~30-300         | ~5-50            |
| Random access (IOPS/sec)    | ~100-200      | ~70,000-140,000 | ~100,000-200,000 |
| Storage cost (MB/US$)       | ~2,000-20,000 | ~300-3,000      | ~100-1,000       |
| Lifespan (years)            | ~1-5          | ~1-3            | ~1-3             |
| Economics (US$/TB/year)     | ~10-500       | ~100-3,000      | 300 - 10,000     |

# Data center limits


# Work smarter not harder


# A game of titans and masterminds


# Ceph will be the next Kubernetes


# Conclusion

-------------

## Innovation and the "S-Curve"

!["A"](https://upload.wikimedia.org/wikipedia/commons/f/f2/Alanf777_Lcd_fig07.png "A")


Hard drive disks are not a new technology in the history of computer storage.
Solid state drives, however, are.
Manufactured by IBM starting in 1957, the first computer to have hard drive disks was the IBM 305 RAMAC.
In the 62 years since then, hard drive disks have gone from ~3.75MB of capacity and ~1.67 IOPS to being able to hold up to 12 TB of data and achieve an average between 100 and 210 IOPS!
Of course, today HDD are generally used for "colder" storage needs.
With modern NVMe solid state drives, we can now get 10,000+ IOPS per drive.
And thus we have begun to see "classes" of storage.
Large amounts of rarely accessed data goes on hard drive disks, to keep storage cheap.
Small amouns of highly accessed data goes on solid state drives, to make workloads that use it fast.
But hard drive disks have one last trick up their sleeve.
And we should care about it because SSDs aren't cheap.


## The Scenario

Let's say you run a business that provides an object store which you've *oh so cleverly* named "T4".
Your business stores binary objects with a replication factor of 1.5 thanks to erasure encoding awesomeness.
Your business has 100PB of storage capability meaning you have 150PB of "raw storage", because of that 1.5x replication factor.

You have two categories for data: hot and cold.
Hot data is accessed at least once an hour.
Cold data is not.
Pretty simple.

The percent of data that is "hot" is 0.1%, or one thousanth of your total storage.
This means that for 100PB of storage, you have 100TB of "hot" data.

As a final metrics, lets say that hot data "churn" is 5% per hour.
This means every hour 5% of the hot data becomes cold and is replaced by an equal amount of data that was cold but has become hot.

## The naive approach

The simplest way to do this is to use economic hard drive disks for the 150PB of raw storage and use solid state drives as a cache for the 100TB of hot data.

If we 

NVMe, short for NVM Express, has been causing waves in the storage industry ever since it was created eight years ago in 2011.
Like all new technologies, it went through a hype curve of how it might "boil the ocean" for the storage world and in the last couple years we've seen a much more stable look at what NVMe can mean for industry.
Much of the excitement in the early days was focused on throughput.
This is because NVMe allows storage to be connected via the PCIe data bus instead of a SATA or SAS connection.
This means you can get an NVMe SSD in 2018 with read and write throughput between 2GBps and 3GBps, if you are willing to pay for it.
But over time people have realized that NVMe has something even more exciting than ludicrious throughput, single digit microsecond I/O latency.
And I want that for a 7200rpm hard drive disk!

## The case for low latency HDD

I know, I probably sound absolutely crazy.
Hard drive disks are known for being big, cheap, and slow!
In fact, let me show you a bit of math to prove it.
A 7200rpm HDD takes a whole 0.083 seconds, or 8,333 μs, to just make a revolution:

$$\frac{7200 \text{ rotations}}{60\text{ seconds}} = \frac{1 \text{  rotation}}{x}$$
<br>

$$x = \frac{(1 \text{  rotation})(60\text{ seconds})}{7200 \text{ rotations}} = 0.08333.. \text{ seconds}$$

So why do we care if the data path from the CPU to the disk is fast or not?

## Hot and cold data

When you're running a storage system, you tend to live in a world of hot and cold data.
Hot data is data that's frequently accessed and cold data is data that isn't.
Is that an extreme oversimplification?
Absolutely!
If we look at the public cloud providers like AWS, they have exabytes of storage.
What percent of it isn't touched more than once a day?
I have no idea, but lets make a guess of 1%.
This means that if I build a storage system out of 4TB 7200rpm disks then I'm only using 40GB of it per day.
And this is where things start to get interesting.

## Putting hot data at the edge

There are two moving components for a HDD, the platter and the needle.
The platter spins at a stable speed, in our case 7200rpm.
The needle, however, is very different.
It's latency is the time it takes to move between sections of the HDD for actions it receives.
Generally the needle is able to achieve random seeks on disk in a similar time it takes for a rotation; approximately 8,000μs to 16,000μs depending on the drive.
For a 7200rpm drive that number tends to be approximately 16,000μs. 
But what about the time to seek a very small distance?
Many enterprise 7200rpm HDD can do a single track seek in only 220μs!
That's a whopping 72x times faster.

So, if we're only accessing 1% of our data on any routine basis we want to put it all together to reduce the amount of time the HDD needles needs to move.

Let's do bit of quick math for a 3.5" HDD.
We'll say the HDD has a usable area from 1" to 3.5" on the drive.
Now, what's the diameter for the outer 1% of the drive?

$$(0.01)(\pi(1.75\text{ inches})^2 - \pi(0.5\text{ inches})^2) = \pi(1.75\text{ inches})^2 - \pi x^2$$
<br>

$$(0.01)((1.75\text{ inches})^2 - (0.5\text{ inches})^2) = (1.75\text{ inches})^2 - x^2$$
<br>

$$x^2 = (1.75\text{ inches})^2 - (0.01)((1.75\text{ inches})^2 - (0.5\text{ inches})^2)$$
<br>

$$x = ~1.741946\text{ inches}$$

This means the outer most 1% of our data fits into a mere 0.008054 inch "band".
This is a very naive calculation, HDD have zones and tracks of different width, but this will suffice for an approximation.

## Understanding seek times

There are hundreds of thousands of tracks on a HDD yet the time to traverse one of them is only ~1/80th the time to traverse all of them.
Let's assume that the 220μs to hop a single track is simply a cost associated with alignment and precision, so it will be paid for all seeks.

If seeking across the entire drive takes 16,000μs then, minus the alignment cost, it takes 15,780μs.
If we assume the drive needle accelerates to a maximum speed, then decelerates, we can come to the following kinematic equation:

$$d = \frac{1}{2}at^2$$
<br>

$$\frac{1.75\text{ inches} - 0.25\text{ inches}}{2} = \frac{1}{2}a(0.0079 \text{ seconds})^2$$
<br>

$$1.75\text{ inches} - 0.25\text{ inches} = a(0.0079 \text{ seconds})^2$$
<br>

$$1.5\text{ inches} = a(0.0079 \text{ seconds})^2$$
<br>

$$a = \frac{1.5\text{ inches}}{(0.0079 \text{ seconds})^2}$$
<br>

$$a = 24,000\frac{\text{inches}}{\text{second}^2} = 610\frac{\text{meters}}{\text{second}^2}$$
<br>

So, what's the time to traverse our chunk of the drive, end to end?

$$d = \frac{1}{2}at^2$$
<br>

$$\frac{0.008054\text{ inches}}{2} = \frac{1}{2}\left(24,000\frac{\text{inches}}{\text{second}^2}\right)t^2$$
<br>

$$0.008054\text{ inches} = \left(24,000\frac{\text{inches}}{\text{second}^2}\right)t^2$$
<br>

$$t = \sqrt{\frac{0.008054\text{ inches}}{24,000\frac{\text{inches}}{\text{second}^2}}}$$
<br>

$$t = 0.000579296\text{ seconds} = 579\text{μs}$$

This gives us 1,158μs to hop across the entire width of our 1% disk edge. This is likely an upper bound as it is possible the head has a high acceleration and traverses the entire disk with some time spent at max velocity.

Total time to seek and read then is, at worst, 1,378μs.

## Getting them IOPS

So, you may be wondering at this point, where are my 725 IOPS?
The answer is, it's complicated:

1. This doesn't factor in time to read data, though that's likely trivial and wouldn't dramatically reduce that number.
2. If data is in parallel tracks we can't read them both, so we have to go a whole rotation to read it again.
3. SATA queue depths are sad sad things.

Remeber that number, one disk rotation ever 8,333μs?
Let's think about the fact that we can peak read at ~230MiBps.
This comes out to ~2MB per rotation.
This also means that our 40GB chunk is ~20,000 tracks!

If we read in 4KB blocks, which is what most modern drives of this size do, we can read 500 blocks per rotation.

How many seeks can we do per rotation? Worst case of almost exactly 6 (6.047 to be exact).
However, we will rarely do this, a traversal of only 50% of the area is:

$$d = \frac{1}{2}at^2$$
<br>

$$\frac{0.008054\text{ inches}}{(2)(2)} = \frac{1}{2}\left(24,000\frac{\text{inches}}{\text{second}^2}\right)t^2$$
<br>

$$0.004027\text{ inches} = \left(24,000\frac{\text{inches}}{\text{second}^2}\right)t^2$$
<br>

$$t = \sqrt{\frac{0.004027\text{ inches}}{24,000\frac{\text{inches}}{\text{second}^2}}}$$
<br>

$$t = 0.000409624\text{ seconds} = 410\text{μs}$$

So average seek will be $410+410+220$ microseconds or 1,040μs.
This gets us 25% more seeks compared to worst case!
Or 8 seeks per rotation.

Of course, this is assuming a perfect world.
If we truly got 8 seeks per rotation we'd get 960 IOPS.
Let's instead look at 5 seeks per rotation and state what we need to achieve this.

If we have 5 seeks per rotation then we get 600 IOPS.
This is HUGE compared to the normal ~100-120 IOPS you get with most drives.

Now... time to talk about SATA, SAS, and NVMe.

| Technology | Queue depth | Round trip latency |
|------------|-------------|--------------------|
| SATA 3     |          31 |              400μs |
| SAS        |         255 |              400μs |
| NVMe       |       1000+ |               20μs |

A modern day NVMe drive will give you ~440,000 IOPS for random read across ~1TB of storage with ~100μs latency, when you account for software.

Using this technique with the above SATA drives will use 25 drives and give you ~15,000 IOPS with average latency of ~4166μs and a horribly long tail.

## References:

1. [http://hddscan.com/doc/HDD_Tracks_and_Zones.html](http://hddscan.com/doc/HDD_Tracks_and_Zones.html)
1. [https://h20195.www2.hpe.com/v2/getpdf.aspx/a00001287enw.pdf?ver=1](https://h20195.www2.hpe.com/v2/getpdf.aspx/a00001287enw.pdf?ver=1)
3. [https://www.ontrack.com/blog/2016/10/18/future-hard-disk-drive-part-2/](https://www.ontrack.com/blog/2016/10/18/future-hard-disk-drive-part-2/)
4. [http://dataidol.com/tonyrogerson/2014/04/07/maximum-iops-for-a-10k-or-15k-sas-hard-disk-drive-is-not-170/](http://dataidol.com/tonyrogerson/2014/04/07/maximum-iops-for-a-10k-or-15k-sas-hard-disk-drive-is-not-170/)
5. [https://storagesearch.com/chartingtheriseofssds.html](https://storagesearch.com/chartingtheriseofssds.html )

-----------------

The latest established version of PCIe is 4.0 which was created in 2017 and allows ~32GB/s of throughput each direction across a device with the maximum number of data lanes.
The path from the PCIe 4.0 standard being established and devices being created for it has been slow.
According to Tom's Hardware, just two months ago the world's first PCIe 4.0 SSD demo happened and was able to achieve 


Project management, leadership, working remotely, team organization, and client relationship management are all topics which have been written about, at length.
However, their combination, as far as I can tell, hasn't been.
This is likely for good reason.
Claiming that one's work falls into the category of *remote-leadership-of-client-project-teams* is, at best, a bizarre way to communicate you have a niche job and, at worst, likely to leave people wondering if you actually have a job.

However, that is a large part of my job.
I do actually have one, for the record, and it involves working remotely as part of a small professional services team which helps clients address complex problems.
We often are involved from the very beginning to end of problems, through the full *problem-lifecycle*, from identifying the problem to solution delivery and long term servicing of those solutions.
The experience of doing this is many things, it's challenging, it's always changing, occasionally it's sleep depriving, but it's rewarding, and it's often fun.
However, it can also be delicate and complex.
A lot of things have to come together in just the right way for *remote-leadership-of-client-project-teams* to work smoothly.
This article is my attempt to share some of my knowledge and wisdom for what is required to do this.
It's far from anything that would be termed "complete" and likely wrong by some opinions.
Never-the-less, I hope that those who stumble across it in their wandering of the Internet find it useful.


# Know what you do: Actions and Accomplishments

The question "So what do you do?" is something I, along with most of humanity, get asked a lot.
I have a variety of answers for this which vary in their degrees of detail.
The simplest one, for those clearly not interested in pursuing an answer much larger than their five syllable question, is "professional services".
On the flip side, when speaking with people who are actually interested and possess a strong technical background, articulating what I "do" isn't as straight forward.

Expressing the details of what I do is challenging because the concept of what someone "does" has more nuance than most people credit it with.
Contrast it with the equally terse question of "where are you going?".
For such a question, both of these are equally valid answers: "to the tea shop" and "on a walk".
What's curious is that these answers aren't incompatible, one can absolutely go on a walk to the tea shop, but that's not always possible with multiple options for an answer.
The options of "to the tea shop" and "to my house" aren't compatible.[[^living_in_a_tea_shop]]
This is because, as you've probably picked up on by now, when referring to changing location there is both the means of transportation and the location you'll arrive at; the journey and the destination; action and accomplishment.

[^living_in_a_tea_shop]: Unless of course you live in a tea shop. Which sounds amazing!

I encourage people to think about what they "do" in this way; to think about the means they have to achieve outcomes and what outcomes they can achieve.
Part of my title says "software engineer",  this is a means of an outcome.
One of the outcomes I often achieve with those means are systems that operate at business level logic, exposing consistent and reliable operations with strong guarantees.
These systems are generally abstractions over multiple unreliable systems which exist in a technical domain, such as system protocols.
The value of such a solution is that it greatly reduces resource demands, often of skilled employee hours, to manage, maintain, and manually maneuver these unreliable technical systems in accordance with business needs.
**That is far move valuable and distinct that the fact that I can "engineer software".**

Clients need solutions and solutions are accomplishments.
But, there can be many roads to a destination and project deadlines often require an efficient one; a keen path; well honed actions.
Be sure to communicate and represent both of these aspects of yourself.
What you can do and how you can do it.
Actions and Accomplishments.


# Leading Ownership: Roles versus Tasks

When working remotely with a clients team, it can be more difficult to manage the project you're working on than a "normal" project.[[^normal_project]]
This stems from two facts: one, that you get far less interaction with the team than if everyone were working together in an office and, two, because you have little to no visibility of happenings outside of the single project you've been hired to do.
Thus issues can occur, often times with little warning from your perspective.
An entire project could become road blocked because a client team member is slow to complete a task only they can do.
Or, perhaps worse, a road block may occur because no one on the client team is willing to do a task even though it has been discussed since early on in the project.

[^normal_project]: A normal project being one that involves people from your own company in an environment where you all interact face to face.

A project's progress can slow for a number of reasons, some of which have no one to directly blame.
Managing such issues is part science, part art.[[^arcane_magic]]
Culture, psychology, individual motives, and deep seated fears are just a few of the forces at play in a team dynamic.
Whole books can, and have, been written on the topic.
Project frameworks, such as Agile, attempt to give structure to projects which remove many causes of project stalling. 
However, what I want to focus on is a specific component of project structuring: ownership.
To explain this, let's start with one of the undesirable scenarios mentioned at the beginning of this section: no one being willing to take on a task.
This often results in either *(option 1)* an overseer of the client team demands (["volun-tells"](/images/voluntold_meme.jpeg)) a team member to do the task, resulting in an angry and overworked team member, or *(option 2)* project progress stalls for some number of days while the deadline doesn't budge an inch resulting in the overseer of the project being unhappy with someone, maybe you.

[^arcane_magic]: And, sometimes, it's part arcane magic.


Neither of the above options is a good one.
Thus the ideal solution to such a problem, when possible, is to prevent it.
The best means I've found to prevent this is having agreed upon "roles" for for a project.
This should be done at the beginning of a project, when you plot the project's initial road map.
The reason and value of doing this is it establishes a long standing expectation which both parties agree to.
This is a far better way to build exceptions compared to tasks.
Tasks, being small units of work, leave only a short window to be completed and thus can overload a team member's already full schedule with no warning.
People are far more likely to push back on tasks because, understandably, it is asking for an immediate commitment which may conflict with others they've already made.
On the flip side, getting someone to agree to fulfill a role means they must accept the role's long term expectations of their time and availability.[[^role_example]]

[^role_example]: To offer an example, suppose your client has a complex monitoring system which the solution is suppose to integrate with. Then by stating, at the beginning of the project, that you need a specialist for the monitoring system who can devote 8 hours a week to this project communicates multiple things. One, that you will not figuring out the clients systems by trial and error, which could eat up tons of project time, but instead it is the client's responsibility to provide you with resources who can assist in such matters. Two, that whoever is placed in the position is aware of the expectations of their time and availability.

The concept of "roles over tasks" is a lose one that depends a lot on the project and team.
But it should prevent some instances the unfavorable situation mentioned above.
**Plus, outcomes tend to be better when people agree to responsibility willingly as they are being accountable for their own word, not someone else's demands.**
This doesn't always happen, but when it does it's the best means of team member motivation I've seen.
At the very least, roles establish the use of long time windows for expectations which are generally more fair and easy to manage for all parties involved.


# Friends with Hidden Faces: Personalities and Context

There are many words that can be used to describe a team, I think one of the most important is synergy.[[^synergy_definition]][[^synergy_example]]
Teams efficiency can be synergistic for a variety of reasons.
Many articles on creating team synergy focuses on frequent positive interaction, communication, building bonds, and building common shared experiences.
All of this, usually, involves spending time with team members "face-to-face", which isn't so easy when working remotely with client teams.

[^synergy_definition]: Synergy, as defined by [The American Heritage Dictionary of the English Language, 4th Edition](http://www.wordnik.com/words/synergy), is *"The interaction of two or more agents or forces so that their combined effect is greater than the sum of their individual effects"* or, in short, the effect of combined components achieving more than the sum of their individual capability.

[^synergy_example]: An example of synergy would be that together three team members could do a certain project in 2.5 weeks while, individual, each team members would take 10 weeks on their own to do the same project. Thus the team can do ~21 projects a year while, if they each worked individually, they could only do ~16 projects a year. Thus the capability of the team is 33% more than the combined capability of its members.

When working remotely with a client team there are basically two things that dictate how many times, if ever, you actually interact face-to-face: in person interactions during the project for "on-site" meetings and whether people use their webcam during remote meetings.
Generally, for my job, I am on site at the beginning of a project where I meet the majority, but rarely all, of the client team in person.
And then, after that, I'm unlikely to get any more face-to-face interaction as no one ever turns on their webcam.
Thus I get between approximately 16 and zero hours of actual "face time" with any member of a client team during the span of a project.
That's not a lot of time for a project that could last, for example, 3 months.

But building connects with team members is important.
Doing so adds context to the people of the team, it helps makes working with one another more enjoyable and also helps individuals understand the personalities of their team members.
And, when your interactions with a team consists primarily of emails, Slack messages, and voice calls, a team member's connection to their team mates goes a long way towards how engaged they are going to be.
**So be sure to spend a bit of time and effort getting to know the people on your team.**

I'm well aware of how cliché the concept of "getting to know the people on your team" is.
This likely isn't new information for you, dear reader.
But it is something that's easy to lose sight of and forget about, especially for a remote team!
So, ask yourself if you can name five topics a specific team member is passionate about which have nothing to do with work.
Strike up conversations with people just to say hi and see how they're doing.
Obviously this is all super contextual to the person (that is the point of this section), but it can go a long way towards having a happier and more productive team.


# Closing Comments

I hope these thoughts prove useful in some way.
For any corrections to this article please post an issue on this [website's Github repository](https://github.com/code-ape/website/).
If you have any comments or thoughts you'd like to share please send them to the email address specified on the [About page](/about) of this site.
