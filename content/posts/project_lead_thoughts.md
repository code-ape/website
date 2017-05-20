+++
title = "Remote Project Lead: Thoughts and Learnings"
date = "2017-05-20"
version = 1
version_history = "https://github.com/code-ape/website/commits/gh-pages/posts/project_lead_thoughts/index.html"
tags = ["Project Management", "Remote Work"] 

summary = '''
Remotely running a project with a distributed team can be challenging.
When that team is mostly from the client who you're doing said project for, it can increase those challenges.
This article shares a few niche lessons I've learned from being in such a position.
'''
+++

*This article is written in present tense and first person to provide a more engaging narrative to the reader. However, all statements and claims are made with the time reference to when this was published. Thus "today" is May 16, 2017.*

*Special thanks to my colleague [Gary Berger](http://firstclassfunc.com/) for providing feedback on this article.*

# Intro

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
