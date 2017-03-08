+++
title = "Math with distances in Rust: safety and correctness across units"
date = "2017-03-06T13:53:17Z"
draft = true
tags = ["Rust Language", "Type Systems"] 
+++

*TL;DR: ...*

Recently [Jasper Schulz](https://github.com/jaheba) wrote an excellent short article titled *[Communicating Intent](https://github.com/jaheba/stuff/blob/master/communicating_intent.md)*.
In it he walks through using the newtype-pattern in combination with the `From` and `Into` traits for the purpose of allowing the compiler to do all datatype checking and transformation.

The reason things like this are useful is, as shown by Schulz in the article, you can write code like this which allows type conversions to be easily handled by the compiler.

```rust
// this function can be passed anything that implements Into<Celcius>
fn danger_of_freezing<T>(temp: T) -> bool
    where T: Into<Celsius>
{
    let celsius = Celsius::from(temp);
    ...
}
```

This pattern is highly useful for safely generalizing parameters on functions but still requires explicit conversion.
What would be nicer is if you could use the units to give meaning to values but let all math not require conversion.
Let me explain what I mean.

*If you're not familiar with the concept of newtype-pattern or the `From` and `Into` trait then I highly recommend reading [Schulz's article](https://github.com/jaheba/stuff/blob/master/communicating_intent.md) before continuing, 
you can also find information on the the topics from official Rust documentation via [the Rust Book (newtype-pattern)](https://doc.rust-lang.org/book/structs.html#tuple-structs) and [code documentation (`From` and `Into`)](https://doc.rust-lang.org/stable/std/convert/).*


# The pain of distances


Let's say I want to compute the circumference of a circle using its radius.
If we set aside the concept of units for a moment then we can do this very easily.

```rust
fn circumference(r: f64) -> f64 {
    2 * r * std::f64::consts::PI
}
```

The problem with this is if you want to find the circumference of a circle with the radius in meters then you are entirely responsible for the unit conversions on the inputs and using the answer correctly.
This becomes even messier when you calculate the hypotenuse of a triangle where the width and height could be different units.
This simply is not the Rust way of doing things, we're manually attempting to manage something our program should guarantee.

Rust's amazing type system is perfect for situations like this.

A simple solution to this would be to do as Schulz did and use the `Into` trait.
Let's assume for this example that we're using meters as our standard unit.

```rust
struct Meters(f64);

fn circumference<R>(r: R) -> Meters where R: Into<Meters> {
    let radius = Meters::from(r);
    Meters(2 * r * std::f64::consts::PI)
}
```

If we're only working in meters then this works well.
Someone who later uses this and wants feet just need to write the `From` trait for the conversion from feet to meters and vice versa.

But let's say we're writing a library where we'll need to use many different units in combination.
As the number of different units increases the number of `From` implementations you have to write explodes.
In fact if you have `n` different types then you'll need `n(n+1)/2` implementations of `From` to convert between them all (for 10 types that's 55 `From`s).
We could absolutely do this, but it's not ideal for the amount of code we have to write.

There are a couple other options to tackle this problem.
One option is to simply write all functions to use meters, or whatever standard is preferred.
This would enforce that all values be converted to meters for the sake of using our library.
But I believe this misses the nature of what we're trying to represent, which is the arithmetic of units of measurement. 

This brings us to the second, more elegant option, which is to unify all units under a single type.
There's one primary reason why I consider this a better solution: it removes the need to explicit conversions during arithmetic.

You see, there's no real reason for the `circumference` function to return meters.
We've made that the default unit in this case but it's very possible for other people to write functions that returns kilometers or inches (plus it's just bad library design to build up code for the sake of working with units but then tie yourself to a single one).
As I mentioned above the result of writing a program with different unit types is that converting between types and formats will be everywhere.
Those constant conversions are unnecessary operations for the computer and unnecessary code for us to write.
What we really want is for our units to offer context for us and the compiler, but not bloat code and slow down computation.

We don't care about the units we're using during arithmetic it if the compiler handles them correctly.
Ideally we should be able to add a foot and a meter and be happy as long as the result accurately reflects the summed length.
That's not to say that the type system isn't useful.
But what we really want the type system to protect us against is adding a measurement of length to a measurement of heat, or especially to a numeric value with no units.

For measurements of the same type we need the type system to correctly translate our intention for a number into the correct measurement representation.
By this we give our system a number with a unit associated with it or receive a number from the system with a unit associated with it.
Between those two points the machine code is indifferent to such things.


## Constructing a unifying base struct and trait

To have the type system to both protect us from doing arithmetic with different measurement types (such as length and mass) while still allowing each measurement to have units associated with it we'll use generic structs ([Rust book reference](https://doc.rust-lang.org/book/generics.html#generic-structs)).
We'll implement a `Length` struct for this.

```rust
// not yet made into a generic struct
#[derive(Debug, Clone, Copy, Eq, Ord)]
struct Length(i64);
```

Before proceeding let's look at why I've implemented the Length struct this way.

To start with, you can see I've choose to use an integer (`i64`) for the length over a floating point number (`f64`).
This is because floating point numbers do are not a reliable arithmetic system as they accrue constant rounding errors.
This may sound sort of silly for anyone who's not familiar with the treachery of floating point arithmetic but it's true.
A floating point number of `0.999` representing millimeters won't survive the conversion to meters and back, you can [try it out here](https://is.gd/BtSSBJ).

I've also asked the compiler to derive three traits.
`Debug` is just for easy inspection of the struct but `Copy` is implemented because this struct simply represents 8 bytes (totaling to the 64 bits in the `i64`). Because of this, on a 64 bit computer, creating a reference to `Length` is just as much work as copying it.
This also means we don't have to worry about borrowing and lifetime parameters as all uses of `Length` will just make a new copy! `Clone` is derived as it must be implemented for `Copy` to be derived.

The other decision that needs to be made is how precise we want to be with our length measurement.
This means we'll have to pick a smallest base unit that we can use to reference all other values.
I realize that this seems like we're just moving back to the other option discussed where we just making all functions take one unit.
This is similar to that solution, and provides the benefits of just having to use one type everywhere, but will allow that type to hold different units.

For simplicity let's assume we're willing to work with a precision limited to nanometers.
If we use an `i64` to represent this it puts our upper bound of distance we can express at ~9.2x10^6 km (around double the circumference of the sun). 

```rust
// not yet made into a generic struct
#[derive(Debug, Clone, Copy, Eq, Ord)]
struct Length(i64); // nanometers
```

This however doesn't allow us to express out previous units of meters and millimeters.
We don't want to implement new structs and traits for them, so the only place to place the data is in the length.

To ascribe information to the Length struct we must add a type option to it like `Length<T>` where `T` relates to the units.
But we don't want to allow just any type, it makes no sense to have `Length<Box<None>>`.
So to limit what we can express the lengths of we need to use a trait, which we'll call `LengthUnit`.

```rust
trait LengthUnit: Copy {
    fn singular_name() -> String;
    fn num_nm_in_unit() -> i64;
}
```

This makes more sense as we can relate all units to our base unit of nano meters and also evaluate their names when needed.
It's worth pointing out that if you are using Rust Nightly there's an easier way to do this via [associated constants](https://doc.rust-lang.org/book/associated-constants.html), but what we do instead will achieve the same result and work on Rust stable.

The last trick is how to tie this back into our `Length` struct.
We can't simply add the trait bound for two reasons:

1. the compiler will complain because it's not related to anything in the struct.
2. we need to be able to reference it when we use our struct.

To do this we'll employ Rust's [PhantomData marker](https://doc.rust-lang.org/std/marker/struct.PhantomData.html) which is super nifty!

```rust
use std::marker::PhantomData;

#[derive(Debug, Clone, Copy, Eq, Ord)]
struct Length<T: LengthUnit> {
    nm: i64,
    unit: PhantomData<T>
}
```

This allows us to have many different variants of length while only using one struct.
But we're still missing the conversions.
Fortunately there's much fewer to worry about this time.
We only have to go from numbers to Length and from one Length type to another Length type.

## Implementing measurement units

Now let's implement `LengthUnit` for meters. To do this we'll create a [unit-like struct](https://doc.rust-lang.org/book/structs.html#unit-like-structs) so we can have a type to work with.

```rust
// derive needed for Length to have same traits available
#[derive(Debug, Copy, Clone, Eq, PartialEq)] 
struct Meters; // unit-like struct

impl LengthUnit for Meters {
    #[inline(always)]
    fn singular_name() -> String { "meter".to_string() }
    #[inline(always)]
    fn num_nm_in_unit() -> i64 { 1_000_000_000 } // billion nanometers in a meter
}
```

As you can see all this really does is store constants in function values, hence why we apply the `#[inline(always)]` attribute.
While we don't use it here, it is possible for these constants to be built using references to other constants.
For example if you wanted to have the number of picometers as we could simply do the following to calculate it using the `num_nm_in_unit` function.

```rust
    #[inline(always)]
    fn num_pm_in_unit() -> i64 { Self::num_nm_in_unit() * 1000 }
```

So that we can have two units to work with we'll also implement millimeters.

```rust
// derive needed for Length to have same traits available
#[derive(Debug, Copy, Clone, Eq, PartialEq)]
struct Millimeters; // unit-like struct

impl LengthUnit for Millimeters {
    #[inline(always)]
    fn singular_name() -> String { "millimeter".to_string() }
    #[inline(always)]
    fn num_nm_in_unit() -> i64 { 1_000_000 } // million nanometers in a millimeter
}
```

As with much of the code in this article, this could easily be made into a macro.
In fact if you look into the Github repo for this article you'll see that I have made this into a macro for convenience. 


## Testing our program so far (1/3)

With the work so far we can run the following code.

```rust
fn main() {
	let l1 = Length<Meters>{nm: 1_000_000_000, unit: PhantomData}
	let l2 = Length<Millimeters>{nm: 1_000_000, unit: PhantomData}
	println!("l1 = {:?}", l1);
	println!("l2 = {:?}", l2);
	// prints the following:
	// l1 = Length { nm: 1000000000, unit: PhantomData }
	// l2 = Length { nm: 1000000, unit: PhantomData }
}
```

This shows our work so far is solid but that debug print isn't actually that helpful.
What we really need is to implement a way of printing our length in a more friendly way.
Let's write a implement `std::fmt::Display` to do this!

```rust
use std::fmt;

impl<T> fmt::Display for Length<T> where T: LengthUnit {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        // convert value in associated units to float value
        let num_val = (self.nm as f64) / (T::num_nm_in_unit() as f64);
        // decide whether or not the unit is plural: meter vs meters
        let name_plural_s = match num_val {
            1_f64 => "",
            _ => "s"
        };
        // write it all
        write!(f,
               "{} {}{}",
               (self.nm as f64) / (T::num_nm_in_unit() as f64),
               T::singular_name(),
               name_plural_s)
    }
}
```

Now our test program give a proper output!

```rust
fn main() {
	let l1 = Length<Meters>{nm: 1_000_000_000, unit: PhantomData}
	let l2 = Length<Millimeters>{nm: 1_000_000, unit: PhantomData}
	println!("l1 = {}", l1);
	println!("l2 = {}", l2);
	// prints the following:
	// l1 = 1 meter
	// l2 = 1 millimeter
}
```


## Converting numbers to Lengths

So you may have noticed that we haven't yet created an easy way to take a number and get a length.
This is of course crucial to our length implementation actually being useful!
This is quickly solved with two simple implementation of `From` allows us to go between an `i64` and a Length with ease.

```rust
impl<T> From<i64> for Length<T> where T: LengthUnit {
    fn from(n: i64) -> Self {
        Length {
            nm: n * T::num_nm_in_unit(),
            unit: PhantomData<T>
        }
    }
}
impl<T> From<Length<T>> for i64 where T: LengthUnit {
    fn from(l: Length) -> i64 {
        ((l.nm as f64) / (T::num_nm_in_unit() as f64)) as i64
    }
}
```

However, doing this for multiple number types would get a bit boring.
Instead here's an easy way to do it via a macro.
I've stuck to only implementing `i64` and `f64` as unsigned integers will lose the the sign of our length and smaller bit sized numbers could possibly overflow.

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
        impl<T> From<Length<T>> for $N where T: LengthUnit {
            fn from(l: Length) -> $N {
                ((l.nm as f64) / (T::num_nm_in_unit() as f64)) as $N
            }
        }
    };
}

ImplFromLengthUnit!(i64);
ImplFromLengthUnit!(f64);

```

## Testing our program so far (2/3)

With the ability to use `into` and `from` for creating lengths from numbers we can make our code much more readable.

```rust
fn main() {
	let l1 = Length<Meters>::from(1);
	println!("l1 = {}", l1);
	// prints the following:
	// l1 = 1 meter
}
```

For sheer usability we can make a `meters!` and `millimeters!` macro to clean this up even more.
This isn't necessary for our code to work but does give a similar feel to what we can do with a macro like `vec!`.

```rust
macro_rules! meters {
    ($num:expr) => (Length::<Meters>::from($num));
}
macro_rules! millimeters {
    ($num:expr) => (Length::<Millimeters>::from($num));
}
```

And with this we finally have a clean two line main function.

```rust
fn main() {
	let l1 = meters!(1);
	let l2 = millimeters!(1);
	println!("l1 = {}", l1);
	println!("l2 = {}", l2);
	// prints the following:
	// l1 = 1 meter
	// l2 = 1 millimeter
}
```


## Implementing std::ops math for lengths

Of course this isn't very useful if we can't do arithmetic with our lengths.
We need to implement addition (`std::ops::Add`) and subtraction (`std::ops::Sub`) for lengths.
We'll also need to implement multiplication (`std::ops::Mul`) and division (`std::ops::Div`) for numbers to scale our values.

Note that multiplication and division of lengths by lengths doesn't yield lengths.
If you're at all familiar with doing math with units this should make perfect sense to you.
Multiplication of two lengths with each other yields an areas.
For example: three meters times one meter is three square meters.
Similarly division cancels units.
For example: three meters divided by one meter is the number three.

For this article we'll implement length by length division but not multiplication.
If we were building a full library doing length by length multiplication is of course reasonable and should be implemented!
But doing that, and subsequently implementing areas, reaches beyond the scope of those article. 

Here's the implementations of `std::ops::{Add, Sub, Mul, Div}` for lengths and numbers in the appropriate way.
Note that we are having length by length division return `f64`s.
This isn't ideal but currently this is the best option for representing decimals (stay tuned for my up and coming posts on my `unums` crate).

```rust
use std::ops::{Add, Sub, Mul, Div};


// Add for two lengths of potentially different units
impl<T1, T2> Add<Length<T2>> for Length<T1>
    where T1: LengthUnit,
          T2: LengthUnit
{
    type Output = Length<T1>;

    fn add(self, other: Length<T2>) -> Length<T1> {
        Length {
            nm: self.nm + other.nm,
            unit: PhantomData,
        }
    }
}

// Subtract for two lengths of potentially different units
impl<T1, T2> Sub<Length<T2>> for Length<T1>
    where T1: LengthUnit,
          T2: LengthUnit
{
    type Output = Length<T1>;

    fn sub(self, other: Length<T2>) -> Length<T1> {
        Length {
            nm: self.nm - other.nm,
            unit: PhantomData,
        }
    }
}

// Divide two lengths to yield a float
impl<T1, T2> Div<Length<T2>> for Length<T1>
    where T1: LengthUnit,
          T2: LengthUnit
{
    type Output = f64;

    fn div(self, other: Length<T2>) -> f64 {
        (self.nm as f64) / (other.nm as f64)
    }
}

// macro to create numeric operations for a length and number
// this makes implementing `i64`s and `f64`s take up less code
macro_rules! ImplMulandDivLengthAndNum {
    ($num_type:ty) => {
        // for Length * $num_type
        impl<T> Mul<$num_type> for Length<T> where T: LengthUnit {
            type Output = Length<T>;
        
            fn mul(self, other: $num_type) -> Length<T> {
                Length {
                    nm: ((self.nm as $num_type) * other) as i64,
                    unit: PhantomData,
                }
            }
        }
        // for $num_type * Length
        impl<T> Mul<Length<T>> for $num_type where T: LengthUnit {
            type Output = Length<T>;
        
            fn mul(self, other: Length<T>) -> Length<T> {
                Length {
                    nm: ((other.nm as $num_type) * self) as i64,
                    unit: PhantomData,
                }
            }
        }
        // for Length / $num_type
        impl<T> Div<$num_type> for Length<T> where T: LengthUnit {
            type Output = Length<T>;
        
            fn div(self, other: $num_type) -> Length<T> {
                Length {
                    nm: ((self.nm as $num_type) / other) as i64,
                    unit: PhantomData,
                }
            }
        }
        // for $num_type / Length
        impl<T> Div<Length<T>> for $num_type where T: LengthUnit {
            type Output = Length<T>;
        
            fn div(self, other: Length<T>) -> Length<T> {
                Length {
                    nm: ((other.nm as $num_type) / self) as i64,
                    unit: PhantomData,
                }
            }
        }
    };
}

ImplMulandDivLengthAndNum!(i64);
ImplMulandDivLengthAndNum!(f64);
```
That is a lot of code, but it's mostly highly repetitive.
It is necessary though.
Without it we can't do math operations using Lengths.
While we're at it there's one set of operation we should implement: comparisons.

Comparisons can be implemented without much code, though they are a bit trickier than implementing arithmetic if you don't have experience with implementing ordering.
Fortunately for us we don't have to worry to much about it as `i64` already has `Ord` implemented.
This means that comparing two different lengths is just `self.nm.cmp(&other.nm)`.
We do however need to implement

```rust
use std::cmp::Ordering;

impl<T1, T2> PartialEq<Length<T2>> for Length<T1> where T1: LengthUnit, T2: LengthUnit {
    fn eq(&self, other: &Length<T2>) -> bool {
        self.nm == other.nm
    }
}

impl<T1,T2> PartialOrd<Length<T2>> for Length<T1> where T1: LengthUnit, T2: LengthUnit {
    fn partial_cmp(&self, other: &Length<T2>) -> Option<Ordering> {
        Some(self.nm.cmp(&other.nm))
    }
}
```

You'll also notice that we didn't have to implement `Eq` or `Ord`.
This is because those traits are only for exactly equivalent types (for example: comparing `Length<Meters>` and `Length<Meters>`).
Thus we simply derived them with our declaration of `Length`.
We did however have to derive `Eq` and `PartialEq` for all declarations of units, such as `Meters`, to satisfy the compiler so that it could compare them when needed for `Eq` and `Ord` which the traits require for their declarations to be valid.



## Generalizing length functions

With all of the mathematical operations implemented we can now easily write the circumference function we started this article with.
Since we have math implemented between `Length`s and `i64`s along with `f64`s the math is very clean.
We can even use Rust's internal constant of pi so we don't have to worry about using our own which wouldn't be consistent with usage of pi elsewhere in the Rust ecosystem.

```rust
fn circumference<T>(r: Length<T>) -> Length<T> where T: LengthUnit {
    2 * r * std::f64::consts::PI
}
```

Its worth noting that we've "shifted" what math looks like.
Generally we only can do operations between matching math types but here we use both an integer (which the compiler figures out should be a `i64` as that's the only integer implemented for `Mul`) and a float (which is an `f64`).
This is because after each operation between a `Length` and a `i64` or `f64` the result is a `Length`.
Because operations are evaluated left to right that means we couldn't write `2 * std::f64::consts::PI * r` because it would first try to multiply `2` by `std::f64::consts::PI`.



## Testing our program so far (3/3)

And with that we can now write our radius program with cleaner code and guaranteed safety of our units!

```rust
fn main() {
    let l1 = meters!(10);
    let l2 = millimeters!(10);
    let l3 = l1 + l2;
    let c1 = circumference(l1);
    println!("l1 = {}", l1);
    println!("l2 = {}", l2);
    println!("l3 = l1 + l2 = {}", l3);
    println!("circumference(radius = {}) = {}", l1, c1);
    println!("c1 > l1 : {}", c1 > l1);
    println!("l1 / l2 = {}", l1 / l2);
}
```

This will print out:

```
l1 = 10 meters
l2 = 10 millimeters
l3 = l1 + l2 = 10.01 meters
circumference(radius = 10 meters) = 62.831853071 meters
c1 > l1 : true
l1 / l2 = 1000
```

Look at that beautifully clean arithmetic with automatic units and safety!
In fact, if you want to verify that this will stop you from doing something that we haven't designed, try multiplying the lengths `l1` and `l2` together.
The compiler will kindly inform you that we can't do this with our system.

```rust
rustc 1.15.1 (021bd294c 2017-02-08)
error[E0277]: the trait bound `Length<Meters>: std::ops::Mul<Length<Millimeters>>` is not satisfied
   --> <anon>:302:14
    |
302 |     let l3 = l1 * l2;
    |              ^^^^^^^ the trait `std::ops::Mul<Length<Millimeters>>` is not implemented for `Length<Meters>`
    |
    = help: the following implementations were found:
    = help:   <Length<T> as std::ops::Mul<i64>>
    = help:   <Length<T> as std::ops::Mul<f64>>

error: aborting due to previous error
```

Now we can write a program with arithmetic of lengths with confidence that we won't do something that breaks the laws of physics.
So if we write a function that takes two lengths and should return a length then dividing the first length by the second will yield a compiler error since that would return a number instead of a length.
You can try it for yourself if you want.

```rust
fn bad_math<T1, T2>(n1: Length<T1>, n2: Length<T2>) -> Length<T1>
    where T1: LengthUnit,
          T2: LengthUnit
{
    n1 / n2
}
```

This will cause the Rust compiler to give us the following error.

```rust
rustc 1.15.1 (021bd294c 2017-02-08)
error[E0308]: mismatched types
   --> <anon>:269:5
    |
269 |     n1 / n2
    |     ^^^^^^^ expected struct `Length`, found f64
    |
    = note: expected type `Length<T1>`
    = note:    found type `f64`
```

# The problem with generic conversions

The final piece of what we would want for this program is to get numbers out of the system in the units we want.
For example, if we were exposing this system through an API that returned its answers in meters then we would want to easily get the numeric value for the length in meters.
However there's a problem if we try this.

```rust
fn main() {
    let l1 = millimeters!(10);
    let l1_meters = f64:from(meters!(l1));
    println!("l1 = {}", l1);
    println!("l1_meters = {}", l1_meters);

}
```

Then Rust's compiler isn't very happy.

```rust
rustc 1.15.1 (021bd294c 2017-02-08)
error[E0277]: the trait bound `Length<Meters>: std::convert::From<Length<Millimeters>>` is not satisfied
   --> <anon>:266:21
    |
266 |     ($num:expr) => (Length::<Meters>::from($num));
    |                     ^^^^^^^^^^^^^^^^^^^^^^ the trait `std::convert::From<Length<Millimeters>>` is not implemented for `Length<Meters>`
...
312 |     let l1_meters = f64::from(meters!(l1));
    |                               ----------- in this macro invocation
    |
    = help: the following implementations were found:
    = help:   <Length<T> as std::convert::From<i64>>
    = help:   <Length<T> as std::convert::From<f64>>
    = note: required by `std::convert::From::from`

error: aborting due to previous error
```

As you can see, the compiler doesn't know how to go from `Length<Meters>` to `Length<Millimeters>`.
It shows the the bottom of the error that it only knows how to convert types of `i64` or `f64`.

This appears simple to fix.
We have the advantage of type generics so all we need to do is implement going from `Length<T1>` to `Length<T2>`.

```rust
impl<T1, T2> From<Length<T1>> for Length<T2>
    where T1: LengthUnit,
          T2: LengthUnit
{
    fn from(l: Length<T1>) -> Self {
        Length {
            nm: l.nm,
            unit: PhantomData,
        }
    }
}
```

As it turns out, however, there's a problem with this...

```rust
rustc 1.15.1 (021bd294c 2017-02-08)
error[E0119]: conflicting implementations of trait `std::convert::From<Length<_>>` for type `Length<_>`:
   --> <anon>:115:1
    |
115 | impl<T1, T2> From<Length<T1>> for Length<T2>
    | ^
    |
    = note: conflicting implementation in crate `core`

error: aborting due to previous error
```

The Rust compiler is stating that this implementation of `From` conflict with one in `core`.
For those of you who are unfamiliar with this sort of message, this is implying that `From` has already been implemented.
Except we know it hasn't.
The reason we're doing this is because we could not convert `Length<Meters>` to `Length<Millimeters>`.
At this point you're likely wondering "what's the issue then?" because the compiler just told us that it didn't have `From` implemented and then when we implement it the compiler says "hold on, I do have an implementation of From".

To shed a bit more light on this let's try making out `From` explicitly `Length<Meters>` to `Length<Millimeters>`.
This isn't what we want to do long term, but we'll try it to see what the compiler makes of it.

```rust
impl From<Length<Millimeters>> for Length<Meters> {
    fn from(l: Length<Millimeters>) -> Self {
        Length {
            nm: l.nm,
            unit: PhantomData,
        }
    }
}
```

And now the compiler is happy as we get the following output.

```
l1 = 10 millimeters
l1_meters = 0.01
```

As it turns out, by default `From` is implemented for identical structs.
This means we get `impl<T> From<Length<T> for Length<T>` for free.
The problem is that the compiler can't differentiate between that implementation and when we use two different generics.
I'm not familiar enough with the Rust compiler to say why this is exactly but I'm not the only one to have stumbled across this problem. User Kornel on [users.rust-lang.org](users.rust-lang.org) posted about this on 16 July 2016 ([https://users.rust-lang.org/t/conflicting-implementations-of-trait-std-convert-from/6427](https://users.rust-lang.org/t/conflicting-implementations-of-trait-std-convert-from/6427)).

So this has been an issue for a while and probably will remain one.
The question then is can how to achieve what we want to while still avoiding this conflict of `From` implementations.

And as it turns out there's a simple way to do this: with references.
From the compilers perspective `Length<_>` and `&Length<_>` are two completed different things.
This means we can do `impl<'a T1,T2> From<&'a Length<T1> for Length<T2>`!

To do this change our previous `impl From<Length<Millimeters>> for Length<Meters>` to the following.

```rust
impl<'a, T1, T2> From<&'a Length<T1>> for Length<T2>
    where T1: LengthUnit,
          T2: LengthUnit
{
    fn from(l: &'a Length<T1>) -> Self {
        Length {
            nm: l.nm,
            unit: PhantomData,
        }
    }
}
```

Now our original program works, but with it's a bit less clean as we have the strange reference in out conversion.

```rust
fn main() {
    let l1 = millimeters!(10);
    let l1_meters = f64:from(meters!(&l1));
    println!("l1 = {}", l1);
    println!("l1_meters = {}", l1_meters);

}
```

This bothers me as it's an unnecessary thing to ask a user to do.
Since `Length` implements copy it's counter intuitive to ask a user to reference it for conversions.
We can solve this by changing our conversion macros to the following.

```rust
macro_rules! meters {
    ($num:expr) => (Length::<Meters>::from(&$num));
}
macro_rules! millimeters {
    ($num:expr) => (Length::<Millimeters>::from(&$num));
}
```

This action, taking a reference of a 64 bit value that implements `Copy`, is counter productive from the standpoint of CPU operations.
However, I'm trusting that the compiler is smart enough to optimize this away.

We've created another problem for ourselves though.
Because of this calling `meters!(10)` won't compile because we haven't declared how to go from a `&i64` to `Length<Meters>`.
Fortunately this can simply be fixed by adding that implementation into the `ImplFromLengthUnit` macro.

```rust
macro_rules! ImplFromLengthUnit {
    ($N:ty) => {
        impl<T> From<$N> for Length<T> where T: LengthUnit {
            fn from(n: $N) -> Self {
                Length {
                    nm: (n as i64) * T::num_nm_in_unit(),
                    unit: PhantomData
                }
            }
        }
        impl<'a, T> From<&'a $N> for Length<T> where T: LengthUnit {
            fn from(n: &'a $N) -> Self {
                Length {
                    nm: (*n as i64) * T::num_nm_in_unit(),
                    unit: PhantomData
                }
            }
        }
        impl<T> From<Length<T>> for $N where T: LengthUnit {
            fn from(l: Length<T>) -> $N {
                ((l.nm as f64) / (T::num_nm_in_unit() as f64)) as $N
            }
        }
    };
}
```

And with that our code is done and all uses of units with lengths can be written as cleanly as possible.

```rust
fn main() {
    let l1 = millimeters!(10);
    let l1_meters = f64:from(meters!(l1));
    println!("l1 = {}", l1);
    println!("l1_meters = {}", l1_meters);
}

// prints
// l1 = 10 millimeters
// l1_meters = 0.01
```

## Closing thoughts

Rust's type system offers a lot of flexibility to express what you want to achieve with your data.
However, it isn't always obvious how to leverage it.
I will fully admit that the system I've worked through in this example wasn't obvious when I first created it (it's initial incarnation was for binding unum contexts to values).
I came to use this pattern after feeling frustrated with constant conversions and the unnecessary code that they required.
Hopefully this article will allow others to find a more elegant and safe way to bind contexts of varying units to data and easily move between them without extra code or performance costs.[^performance_size]

[^performance_size]: For the record you can use `use std::mem::size_of::Length<Meters>()` to verify that `Length` is in fact only eight bytes in size, meaning we've achieved this system without adding runtime memory cost. Such is the beauty of the Rust compiler.


