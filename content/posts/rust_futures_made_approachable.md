+++
title = "Rust Futures, Made Approachable"
date = "2018-07-04"
version = 1
version_history = "https://github.com/code-ape/website/commits/gh-pages/posts/rust_futures_made_approachable/index.html"
tags = ["Rust Language", "Futures", "Event Driven Software"] 

summary = '''
TODO
'''

draft = true

+++


# Backstory

Last week I went about building a webscraper in Rust.
A web scraper is effectively a simple one way filter that takes network data, from a ton of HTTP requests filters that data however you program it to, and writes the results to disk.
Therefore, I thought I'd write it to be event driven and feel accomplished by having a super efficient little scraper that tons of asyncronous HTTP requests and asyncronous disk writes using one thread and a couple MB of RAM.
*That, unfortunately, is not what happened.*

Over 4 hours later and after reading through many, arguably poorly cross linked, documentation pages (and as I would later find out, stale versions of some of them) I managed to get the barest example imaginable running: asyncronously adding 2 numbmers.

However, this isn't because doing this is particularly laborsome.
Instead it appears to be because no one has documented how all the pieces of Rust's current asyncronous pieces.
Making this more tragic is that, once you figure out how they fit together, it's really a beautifully created system: Futures, Tokio, and crates that allow you to use them for what you want, such as Hyper allowing you to use them with HTTP requests and servers. 

This blog post is the first in a series to make this entire system approachable.
I say "approachable", instead of "simple" or "easy", because my honest opinion is that event driven software is just not "simple" or "easy".
Writing event driven software means your code can never "just wait a moment" for something to complete.
You have to wire an entire piece of software up in piecemeal chunks which you then must correctly compose before executing.
Approachable seems like a realistic way to talk about this.


# Realizing Futures

Future are the most primitive form of an event driven piece of software.
They disconnect the most basic thing you'd expect a program to do: call a function and get a result.
Instead of waxing and waning over the mental model around this, let's start with an example: adding two numbers. We'll start with the normal syncronous way of doing this, which is super straightforward.

```rust

// Syncronous addition of 2 usize numbers.
fn sync_add(n1: usize, n2: usize) -> usize {
    println("sync_add running")
    n1 + n2
}

fn main() {
    let result = sync_add(3,5);
    println!("(synchronous) 3 + 5 = {:?}", result);
}
```

So far so good. We run this and see the following output:


```
sync_add running
(synchronous) 3 + 5 = 8
```

Now, let's make it to where we can call the function to add the numbers, but defer it actually executing until later.
Some languages refer to this as "lazy execution", which means that a function doesn't actually get called until we try to do something with its result.
You may be wondering "What the bloody hell is the purpose of deferring a function running from when it was called?!" and if so don't worry, we'll get to that.

## Using the `Futures` crate.

Let's start by using the `Futures` crate.
The versioning around this crate seems a bit wonky at the moment.
If you look on Crates.io you'll see that there are multiple releases of version 0.2, however they've all been yanked meaning the authors don't recommend using them.
The most up to date crate version is 0.1.21, released April 2, 2018.
So into our `Cargo.toml` it goes.

```toml
[dependencies]
futures = "0.1.21"
```

Now, time to make a asynchronous version of our addition function from above.
To begin with, let's outline the structure of how Futures work in Rust.

Normally a function has a return value.
Instead we want to return a "future".
We'll get to the details of what exactly a future is in a moment, to start with let's just say it returns an `AddFuture`.

```rust
fn async_add(n1: usize, n2: usize) -> AddFuture {
    ...
}
```

This `AddFuture` is something that needs to know all the details to do the work of our function at a later time, so let's make a `struct` for it which holds the two values:

```rust
#[derive(Debug)]
struct AddFuture {
    n1: usize,
    n2: usize
}

fn async_add(n1: usize, n2: usize) -> AddFuture {
    AddFuture { n1: n1, n2: n2 }
}
```

At this point you may be wondering what on earth is special about this, as our program is now:

```rust
extern crate futures;

#[derive(Debug)]
struct AddFuture {
    n1: usize,
    n2: usize
}

fn async_add(n1: usize, n2: usize) -> AddFuture {
    println!("creating AddFuture");
    AddFuture { n1: n1, n2: n2 }
}

fn main() {
    let result = async_add(3,5);
    println!("(async) 3 + 5 = {:?}", result);
}
```

And this isn't a helpful program.
We run this and see the following output:


```
creating AddFuture
(async) 3 + 5 = AddFuture { n1: 3, n2: 5 }
```

So, now we need to "realize" this future.
The `futures` create has a mechanism to do this, but it requires us to implement the `futures::Future` trait which is how we explain the work to be done for our future to be realized.

If you dare to look at the `futures::Future` trait documentation you may be terrified by the number of functions that comprise it.
Don't worry, there's only a three things we have to declare for the trait:

1. `type Item`: What we'll be returning upon success of the work for the future.
2. `type Error`: What we'll be returning upon failure of the work for the future.
3. `fn poll(&mut self) -> Result<futures::Async<Self::Item>, Self::Error>`: The function that get's called to do the work and returns whether the work is done or whether we should check back later again. Hence the name poll.

In our case, the item we're returning is `usize`, the error we may return is going to be `()` because we are just adding things so there is no error, and the poll function is going to return the addition of our two numbers, wrapped in `Ok(futures::Async::Ready(...))` which means that we're done and succeeded.

```rust


impl futures::Future for AddFuture {
    type Item = usize;
    type Error = ();

    fn poll(&mut self) -> Result<futures::Async<Self::Item>, Self::Error> {
        println!("Polling AddFuture.");
        Ok(futures::Async::Ready(self.n1 + self.n2))
    }
}
```

Of course, we can include the following code in our example but that doens't cause anything more to happen.
We need a way to "realize" the future.
Enter stage left: `wait`.
This is a function we can call on a future that will execute it, blocking the thread with its execution until it is done.

Combining out entire example yields the following code.
Note that the return name of `async_add` has been updated to


```rust
extern crate futures;

// Needed to use methods of trait in `main`.
use futures::Future;

#[derive(Debug)]
struct AddFuture {
    n1: usize,
    n2: usize
}

fn async_add(n1: usize, n2: usize) -> AddFuture {
    println!("creating AddFuture");
    AddFuture { n1: n1, n2: n2 }
}

impl futures::Future for AddFuture {
    type Item = usize;
    type Error = ();

    fn poll(&mut self) -> Result<futures::Async<Self::Item>, Self::Error> {
        println!("Polling AddFuture.");
        Ok(futures::Async::Ready(self.n1 + self.n2))
    }
}

fn main() {
    let add_fut = async_add(3,5);
    println!("(async) 3 + 5 = {:?}", add_fut);

    println!("Realzing add_fut and blocking until it completes.");
    let result = add_fut.wait();
    println!("result = {:?}", result);
}
```

# Why should I care?

So, admittedly the example above is trivially useless for actual software projects.
We don't need to have futures for addition.
However, the power of this comes from two things:

1. The ability to poll a lot of things at once.
2. The ability to create work flows of things.

Together this allows us to do things like open up 1,000 HTTP connections using a single thread and have extremely fast and efficient transaction of data on them.
This is because the thread is able to hop back and forth between the connections, checking if they are ready and doing work only when they are.

Let's start by making an example of the first one: running a lot of futures at once in parallel.


# Parallel, Unordered, Chained Futures

```rust
extern crate futures;
extern crate rand;
extern crate futures_timer;

use rand::Rng;
use futures::Future;
use futures::stream::Stream;
use std::time;
use std::fmt;


#[derive(Debug)]
struct AddFuture {
    n1: usize,
    n2: usize,
    duration: time::Duration
}

impl fmt::Display for AddFuture {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "AddFuture(n1={}, n2={}, duration={}.{}secs)",
            self.n1, self.n2, self.duration.as_secs(), self.duration.subsec_millis()
        )
    }
}

fn async_add(n1: usize, n2: usize) -> impl futures::Future<Item=usize,Error=()> {
    let mut rng = rand::thread_rng();
    let duration = time::Duration::from_millis(rng.gen_range(0,5000));

    let add_fut = AddFuture { n1: n1, n2: n2, duration: duration };

    println!("created {}", add_fut);

    futures_timer::Delay::new(duration)
        .map_err(|err| {
            println!("Error = {}",err);
            ()
        })
        .and_then(move |_| {
            add_fut
        })
}

impl futures::Future for AddFuture {
    type Item = usize;
    type Error = ();

    fn poll(&mut self) -> Result<futures::Async<Self::Item>, Self::Error> {
        println!("polling {}",self);
        Ok(futures::Async::Ready(self.n1 + self.n2))
    }
}


fn main() {
    let mut add_futures: Vec<_> = Vec::new();
    for i in 0..5 {

        let add_fut = async_add(i,i).and_then(
            |x| async_add(x,100)
        );

        add_futures.push(add_fut);
    }

    let results = futures::stream::futures_unordered(add_futures)
        .collect()
        .wait();

    // let's run the futures
    println!("results = {:?}", results);

}
```

# Process futures using channel

```rust
fn main() {

    let (mut tx, mut rx) = futures::unsync::mpsc::channel(100);

    for i in 0..10 {
        let r = tx.send(i);
        tx = r.wait().unwrap();
    }

    println!("tx.close() = {:?}",tx.close().unwrap());
    println!("rx.close() = {:?}",rx.close());

    // let's run the futures
    let results = rx
        .map(move |x| {
            async_add(x,x)
        })
        .buffer_unordered(3)
        .collect()
        .wait();

    println!("results = {:?}", results);

}
```

# Have future loop populate channel

```rust
fn main() {

    let (mut tx, mut rx) = futures::unsync::mpsc::channel(100);

    for i in 1..5 {
        let r = tx.send(i);
        tx = r.wait().unwrap();
    }

    // This will run indefinitely
    let results = rx
        .map(|x| {
            async_add(x,x)
                .and_then(|y| {
                    tx.clone().start_send(y).unwrap();
                    Ok(y)
                })
        })
        .buffer_unordered(3)
        .collect()
        .wait();

}
```
