+++
title = "Configurable structs in Rust"
date = "2017-03-06T13:53:17Z"
draft = true
+++


Recently [Jasper Schulz](https://github.com/jaheba) wrote an excellent short article titled *[Communicating Intent](https://github.com/jaheba/stuff/blob/master/communicating_intent.md)* where he walks through using the newtype-pattern in combination with the `From` and `Into` traits to allow the compiler to do the work of datatype checking and transformation.
I recently have employed a pattern built upon this concept to accomplish, what I've termed, **configurable structs**.

If you're not familiar with the concept of newtype-pattern or the `From` and `Into` trait then I highly recommend reading [Schulz's article](https://github.com/jaheba/stuff/blob/master/communicating_intent.md) before continuing, 
you can also find information on the the topics from official Rust documentation via [the Rust Book (newtype-pattern)](https://doc.rust-lang.org/book/structs.html#tuple-structs) and [code documentation (`From` and `Into`)](https://doc.rust-lang.org/stable/std/convert/).

## An extendable measurement system

Suppose you want to use measurements in your program, you're a scientist so your units are meters.
Since you're familiar with the newtype-pattern you've got some code that looks like this.

```rust
struct Meters{f64};
```

This works fine until you need to work with data that's in millimeters.
To ensure correctness in your code you leverage the type system by making another newtype struct and then implement `From` both ways for easy conversion.

```rust
struct Meters{f64};
struct MilliMeters{f64};


impl From<Meters> for MilliMeters {
    fn from(m: Meters) -> Self {
        MilliMeters(m.0 * 1000)
    }
}

impl From<MilliMeters> for Meters {
    fn from(mm: MilliMeters) -> Self {
        Meters(mm.0 / 1000)
    }
}
```

This works reasonably well but you notice two main problems:

1. You can't rely on this implementation for computing because the float conversions cause errors.
This may sound sort of silly for anyone who's not familiar with the trechary of floating point arithmatic but it's true.
A measurement of 0.999 meters won't survive the converstion to millimeters and back, you can [try it out here](https://is.gd/BtSSBJ).
2. This isn't easy to extend as each new type you add in the future, for example kilometers, requires more and more implementations of `From`.
In fact if you have `n` different types then you'll need `n(n+1)/2` implementations of `From` to convert between them all (for 10 types that's 55 `From`s). 

## A configurable measurement system

So here's how we can solve both theses problems at once.
As you can you see from the two problems above, having a different struct for each type is going to cause a lot of mess in trait implementations of `From` for each conversion.
We could make that less painful by using macros but it's still not very clean.

So instead of having different structures for each type lets start with just one.
Also to avoid the pains of rounding errors we'll strictly use integers.
For simplicity let's assume we're willing to work with a precion limited to nanometers, which puts our upper bound of distance we can express at ~9.2x10^6 km (around double the circumference of the sun). 

```rust
struct Length{i64}; // nanometers
```

This however doesn't allow us to express out previous units of meters and millimeters.
We don't want to implement new structs and traits for them, so the only place to place the data is in the length.

To ascribe information to the Length struct we must add a type option to it like `Length<T>` where `T` relates to the units.
But we don't want to allow just any type, it makes no sense to have `Length<Box<None>>` after all.
So to limit what we can express Lengths of we need a trait, which we'll call `LengthUnit`.

```rust
trait LengthUnit {
    fn singular_name() -> String;
    fn num_nm_in_unit() -> i64;
}
```

This makes more sense as we can relate all units to out base unit of nano meters and also evaluate their names when needed.
It's worth pointing out that if you are using Rust Nightly there's an easier way to do this via [associated constants](https://doc.rust-lang.org/book/associated-constants.html), but what we do instead will achieve the same result and work on Rust stable.

So now let's implement `LengthUnit` for meters. To do this we'll create a [unit-like struct](https://doc.rust-lang.org/book/structs.html#unit-like-structs) so we can have a type to work with.

```rust
struct Meters; // unit-like struct

impl LengthUnit for Meters {
    #[inline(always)]
    fn singular_name() -> String { "meter".to_string() }
    #[inline(always)]
    fn num_nm_in_unit() -> i64 { 1e9 }
}
```

So we new have a the trait we want, `LengthUnit`, implemented for a unit we want, `Meters`.
The last trick is how to tie this back into our `Length` struct.
We can't simply add the trait bound for two reasons: (1) the compiler will complain and (2) we need to be able to reference it when we use our struct.
To do this we'll employ Rust's [PhantomData marker](https://doc.rust-lang.org/std/marker/struct.PhantomData.html) which is super nifty!

```rust
use std::marker::PhantomData;

struct Length<T: LengthUnit> {
    nm: i64,
    unit: PhantomData<T>
}
```

This allows us to have many different varients of length while only using one struct.
But we're still missing the conversions.
Fortunately there's much fewer to worry about this time.
We only have to go from numbers to Length and from one Length type to another.

## Macros make life easier

```rust
macro_rules! ImplFromLengthUnit {
    ($N:ty) => {
        impl<T> From<$N> for Length<T> where T: LengthUnit {
            fn from(n: $N) -> Self {
                Length {
                    nm: (n as i64) * T::num_nm_in_unit(),
                    unit: PhantomData<T>
                }
            }
        }
        impl<T> From<&Length<T>> for $N where T: LengthUnit {
            fn from(l: &Length) -> $N {
                ((l.nm as f64) / (T::num_nm_in_unit() as f64)) as $N
            }
        }
    };
}
```

```rust
impl<T1, T2> From<&Length<T1>> for Length<T2> where T1,T2: LengthUnit {
    fn from(l: &Length<T1>) -> Self {
        Length {
            nm: l.nm, 
            unit: PhantomData<T2>
        }
    }
}
```  

Rust's type system offers a lot of fexability to express what you want to achieve data and types.
However, it isn't always obvious how to leverage it.

