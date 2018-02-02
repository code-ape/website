+++
title = "Math with distances in Rust: safety and correctness across units"
date = "2017-03-08"
tags = ["Rust Language", "Type Systems"] 

summary = '''
Computers weren't designed to have outside concepts, such as units of length, expressed in their function.
Because of this Rust, being a systems language, also has no concept of it.
But just because the computer runtime has no concept of length or units of length doesn't mean we can't teach them to the compiler.
In this article I'll walk through using a generic struct to represent the concept of a length, extend that length to allow any units, and show how to create a system to cleanly and safely do arithmetic with lengths.
'''

repository = "https://github.com/code-ape/rust_length_arithmetic_example"

version = 3
version_history = "https://github.com/code-ape/website/commits/gh-pages/posts/rust-implementing-units-for-types/index.html"
+++

Recently [Jasper Schulz](https://github.com/jaheba) wrote an excellent short article titled *[Communicating Intent](https://github.com/jaheba/stuff/blob/master/communicating_intent.md)*.
In it he walks through using the newtype-pattern in combination with the `From` and `Into` traits for the purpose of allowing the compiler to do all datatype checking and transformation.

The reason things like this are useful is, as shown by Schulz in the article, you can write code which allows type conversions without knowing what your converting from.
This allows the actual conversion logic to be easily handled by the compiler.

```rust
// this function can be passed anything that implements Into<Celcius>
fn danger_of_freezing<T>(temp: T) -> bool
    where T: Into<Celsius>
{
    let celsius = Celsius::from(temp);
    ...
}
```

This pattern is highly useful for safely generalizing inputs to functions.
One thing that is less than ideal about it, however, is it still requires explicit conversion from the input to celcius.
On top of this, there's no way for a single entity to represent all temperatures.
This is important because conversions, like the one above, form a new struct with a different value and thus require work from the CPU.
What would be better is if units could be used to give meaning to values while math done with those values was uniform and thus did not requiring unnecessary work from the CPU.
Let me show what I mean by that.

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

Rust's amazing type system is made for situations like this.
What we want to do is explain how lengths should relate to actions and types in our program and let the compiler do the rest.

A simple solution to this would be to do as Schulz did and use the `Into` trait.
Let's assume for this example that we're using meters as our standard unit.

```rust
struct Meters(f64);

fn circumference<R>(r: R) -> Meters where R: Into<Meters> {
    let radius = Meters::from(r);
    Meters(2 * r.0 * std::f64::consts::PI)
}
```

If we're only working in meters then this works well.
Someone who later uses this and wants to use units of feet just need to write the `From` trait for the conversion from feet to meters and vice versa.

But let's say we're writing a library where we'll need to use many different units in combination.
As the number of different units increases the number of `From` implementations you have to write grows rapidly.
In fact if you have `n` different types then you'll need `n(n+1)/2` implementations of `From` to convert between them all (for 10 types that's 55 `From` implementations).
We could absolutely do this, but it's not ideal for the amount of code we have to write.

There are a couple other options to tackle this problem.
One option is to simply write all functions to use meters, or whatever standard is preferred.
This would enforce that all value were converted to meters for the sake of using our library.
But I believe this misses the nature of what we're trying to represent, which is the arithmetic of measurement. 

This brings us to the second, more elegant option, which is to unify all units under a single type.
There's one primary reason why I consider this a better solution: it removes the need for explicit conversions during arithmetic.

I consider this a huge benefit for a few reasons.
To begin with there is no reason why the `circumference` function should return meters as opposed to any other unit.
In the example above the unit of meters was made the primary return and computation unit.
However, it is entirely reasonable for other people to want to write functions that do operations in kilometers or inches (plus it is just bad design to build a library for working with different units and then tie yourself to a single unit).
As I mentioned above the result of writing a program with different unit types is that converting between types and formats will be everywhere.
Those constant conversions are unnecessary operations for the computer and unnecessary code for us to write.
What is really desired is for units to offer context for us and the compiler, but not bloat code and slow down computation.

Ideally we should be able to add a foot and a meter and be happy with the resulting value so long as the it accurately reflects the summed length.
That's not to say that the unit of length isn't useful.
But what we really want the type system to protect us against is adding a measurement of length to a measurement of heat, or especially to a numeric value with no units at all.
Adding measurements of length simply should produce measurements of length.
The only time we care about conversions with units of said length is when a number enters the system (example: inputing 10 meters) or exits the system (example: asking for the answer in millimeters).



# Constructing a unifying base struct and trait

For type system to protect us from doing arithmetic with different measurement types (such as length and mass) while still allowing each measurement to have unique units associated with it  we will need to use a generic struct ([Rust book reference](https://doc.rust-lang.org/book/generics.html#generic-structs)).
We'll implement this generic struct with the name `Length`.

```rust
// not yet made into a generic struct
#[derive(Debug, Clone, Copy, Eq, Ord)]
struct Length<T>{
	val: i64,
	...
};
```

Before proceeding to the generic trait we'll use with the `Length` struct I'd like to pause to look at why I've implemented the Length struct this way.

To start with, you can see I've choose to use an integer (`i64`) for the length instead of a floating point number (`f64`).
This is because floating point numbers are not reliable for arithmetic due to the rounding errors that occur when using them.
This may sound sort of silly for anyone who is not familiar with the treachery of floating point arithmetic but is it a fact.
A floating point number of `0.999` representing millimeters won't survive the conversion to meters and back, you can [try it out here](https://is.gd/BtSSBJ) if you don't believe me.

It's also worth pointing out that I've asked the compiler to derive five traits.
`Debug` is just for easy inspection of the struct but `Copy` is implemented because this struct simply represents 8 bytes (totaling to the 64 bits in the `i64`). Because of this creating a reference to a `Length`, on a 64 bit computer, is just as much work for the computer as copying it.
This also means we don't have to worry about borrowing and lifetime parameters as all uses of `Length` will just make a new copy! `Clone` is derived as it must be implemented for `Copy` to be derived.
The traits `Eq` and `Ord` will be needed later when we implement `PartialEq` and `PartialOrd`.

The decision that needs to be made for this `Length` struct is how precise we want to be with measurements.
This means picking a smallest base unit that we can use to reference all other values.
I realize this may seem like moving back to towards other option discussed earlier: just making all functions take one unit.
This implementation of `Length` is similar to that solution, and provides the benefits of just having to use one type everywhere, but will allow that type to hold different units.

For simplicity let's assume we're willing to work with a precision limited to nanometers.
If we use an `i64` to represent this it puts our upper bound of distance we can express at ~9.2x10^6 km (around double the circumference of the sun). 

```rust
// not yet made into a generic struct
#[derive(Debug, Clone, Copy, Eq, Ord)]
struct Length<T>{
	nm: i64, // nanometers
	...
};
```

This, however, doesn't allow us to express the units of meters and millimeters.
To add information to the `Length` struct we must add units using the `T` in `Length<T>`.
But we don't want to allow just any type, it makes no sense to have `Length<Box<None>>`.
So to limit what we can express the lengths of we need to use a trait, which we'll call `LengthUnit`.

```rust
// Copy must be implemented so Length can be copied
trait LengthUnit: Copy {
    fn singular_name() -> String; // unit name, singular
    fn num_nm_in_unit() -> i64; // number of nanometers in unit
}
```

This makes more sense as we can relate all units to our base unit of nano meters using `num_nm_in_unit` and also evaluate their names when needed using `singular_name `.
It is worth pointing out that using Rust Nightly this can be done more easily with [associated constants](https://doc.rust-lang.org/book/associated-constants.html), but this way will achieve the same result and work on Rust stable.

The last trick is how to tie this back into our `Length` struct.
We can't simply add the trait bound and not use it anywhere as the compiler will complain because it's not related to anything in the struct.

To do this we'll employ Rust's PhantomData marker which is super nifty!
I won't go deep into what Phantom data as [Rust's documentation](https://doc.rust-lang.org/std/marker/struct.PhantomData.html) does a good job of walking through it.
The super short explanation is that PhantomData is for these situations of associating a type to a struct without using in any of the data fields.

```rust
use std::marker::PhantomData;

#[derive(Debug, Clone, Copy, Eq, Ord)]
struct Length<T: LengthUnit> {
    nm: i64,
    unit: PhantomData<T>
}
```

This accomplishing being able to have many different variants of length while only using one struct.
But this is not helpful unless we actually have some units that implement it.

# Implementing measurement units

Now let's implement `LengthUnit` for meters. To do this we'll create a [unit-like struct](https://doc.rust-lang.org/book/structs.html#unit-like-structs) so we can have a type to work with without taking up any memory when we use it.

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

As you can see all this does is store constants in functions.
This is why the `#[inline(always)]` attribute is applied to them.
Using it avoids having the compiler treat the functions as functions in the machine code which makes them a tiny bit more efficient for the computer.
Also, for those who may want to use this pattern with to hold more complex information, it is possible for these constants to be built using references to other constants.[^picometers]

[^picometers]: For example if you wanted to have the number of picometers as we could simply do the following to calculate it using the `num_nm_in_unit` function: `fn num_pm_in_unit() -> i64 { Self::num_nm_in_unit() * 1000 }`

For the sake of having two units to work with I'll also implement millimeters.

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

As with much of the code in this article this process could easily be made into a macro.
In fact if you look into the [Github repo](https://github.com/code-ape/rust_length_arithmetic_example) for this article you'll see that I have [made this into a macro for convenience](https://github.com/code-ape/rust_length_arithmetic_example/blob/master/example.rs#L20).
References to the example repository can only be found at the beginning and end of this article.


# Testing the program so far (1/3)

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

This shows all the code thus far is solid but that debug print isn't actually that helpful.
What would be better is to printing our length in a more friendly way.
Let's write a quick implementation of `std::fmt::Display` to do this!

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


# Converting numbers to Lengths

Thus far I haven't created an easy way to take a number with a unit and get a length.
This is of course crucial to this code actually being useful.
Two simple implementations of `From` solve this problem allowing conversion between `i64` and a `Length` with ease.

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
         // non-ideal but un-avoidable with standard numbers
         ((l.nm as f64) / (T::num_nm_in_unit() as f64)) as i64
    }
}
```

That was easy but implementing `From` for multiple number types is a bit boring and wasteful.
Instead here's an easy way to do this via a macro.
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

# Testing the program so far (2/3)

With the ability to use `into` and `from` for creating lengths from numbers we can make our prior code more readable.

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


# Implementing std::ops math for lengths

Of course having `Length`s isn't very useful without the ability to do arithmetic with them.
For operations on these lengths to reflect how units work in physics an implementation of addition (`std::ops::Add`) and subtraction (`std::ops::Sub`) must be implemented for lengths.
We'll also need to implement multiplication (`std::ops::Mul`) and division (`std::ops::Div`) for numbers so they can scale lengths just like in physics.

Note that multiplication and division of lengths by lengths doesn't yield lengths.
If you're at all familiar with physics this should make perfect sense.
Multiplication of two lengths with each other yields an area, for example: three meters times one meter is three square meters.
Similarly division cancels units leaving just a number, for example: three meters divided by one meter is the number three.

This article will implement length by length division but not multiplication.
If the goal were building a full library for physical units then doing length by length multiplication should absolutely be implemented to yield an area!
But doing that, and subsequently implementing areas, reaches beyond the scope of those article. 

Below is the implementations of `std::ops::{Add, Sub, Mul, Div}` for lengths and numbers as reflective of how they work in physics.
Note that length by length division return `f64`s.
Casting to floats in this way, from the length's `i64` values, is not ideal but currently is the best option for representing decimals (stay tuned for an up and coming posts on my `unums` crate).

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
That's a lot of code and highly repetitive code at that, even with the `ImplMulandDivLengthAndNum ` macro.
It is necessary code though and considering this essentially defines a custom algebra I find it to be plesantly concise.
While on the topic of implementing operation traits, there is one other set of operation we should implement: comparisons.

Comparisons implementations are much less code than above.
However, `PartialOrd` can be tricky if you don't have prior experience with ordering in Rust.
Fortunately there's no need to worry about that in this case as `i64` already has `Ord` implemented.
This means that comparing two different lengths is just `self.nm.cmp(&other.nm)`.

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

You will also notice that there was not need to implement `Eq` or `Ord` as they were derived them with the declaration of `Length` previously.
It's worth noting that the reason those traits can be derived is because those traits operate on exactly equivalent types (for example: comparing `Length<Meters>` and `Length<Meters>`).
The above code also won't work if `Eq` and `PartialEq` weren't derived for all declarations of units, such as `Meters`.
This is because they're required to satisfy the compiler so that it can compare them when needed for `Eq` and `Ord` which the traits require for their declarations to be valid.



# Generalizing length functions

With all of the mathematical operations implemented we can now easily write the circumference function we started this article with.
Since we have math implemented between `Length`s and `i64`s along with `f64`s the math is very clean.
We can even use Rust's internal constant of pi so we don't have to worry about using our own which wouldn't be consistent with usage of pi elsewhere in the Rust ecosystem.

```rust
fn circumference<T>(r: Length<T>) -> Length<T> where T: LengthUnit {
    2 * r * std::f64::consts::PI
}
```

It's worth noting that this "morphs" what math looks like normally in Rust.
Generally only operations between matching number types are allowed but here an integer, a float, and a length are all use together in one statement.
This is because after each operation between a `Length` and a `i64` or `f64` the result is a `Length`.
Because operations are evaluated left to right that means we couldn't write `2 * std::f64::consts::PI * r` because it would first try to multiply `2` by `std::f64::consts::PI`.



# Testing our program so far (3/3)

With that a program using the circumference function can be written with cleaner code, guaranteed safety of units, and also allowing all valid operations with units.
Here is a short demonstration of this.

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

    // This will print out:
    // l1 = 10 meters
    // l2 = 10 millimeters
    // l3 = l1 + l2 = 10.01 meters
    // circumference(radius = 10 meters) = 62.831853071 meters
    // c1 > l1 : true
    // l1 / l2 = 1000
}
```

Look at that beautifully clean arithmetic with automatic units and safety!
In fact, if you want to verify that this will stop you from doing something that we haven't designed, you can try multiplying the lengths `l1` and `l2` together.
The compiler will kindly inform you that we can't do this with our system.

```rust
rustc 1.15.1 (021bd294c 2017-02-08)
error[E0277]: the trait bound `Length<Meters>: std::ops::Mul<Length<Millimeters>>` is not satisfied
   --> <anon>:302:14
    |
302 |     let _ = l1 * l2;
    |              ^^^^^^^ the trait `std::ops::Mul<Length<Millimeters>>` is not implemented for `Length<Meters>`
    |
    = help: the following implementations were found:
    = help:   <Length<T> as std::ops::Mul<i64>>
    = help:   <Length<T> as std::ops::Mul<f64>>

error: aborting due to previous error
```

Now it is possible to write a program using arithmetic on lengths with confidence that nothing can happen that voildates the laws of physics.
So a function that takes two lengths and should return a length instead dividing the first length by the second then the compiler will error since that would return a number instead of a length.
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

The final piece of crucial functionality for this demo program is to get numbers out of the system in the desired units of the user.
For example, if this system were exposed through an API that returned answers in meters then as a developer we would want to easily get the numeric value for all lengths in meters once they've been computed.
However there is a problem with doing this.

```rust
fn main() {
    let l1 = millimeters!(10);
    let l1_meters = f64:from(meters!(l1));
    println!("l1 = {}", l1);
    println!("l1_meters = {}", l1_meters);

}
```

The Rust's compiler gets unhappy.

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

Fixing this appears simple.
Since `Length` is a generic struct all that should be needed is an implement of `From` that will convert `Length<T1>` to `Length<T2>`.

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

As it turns out, however, there is a problem with this...

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
For those of you who are unfamiliar with this sort of message, this is implying that `From` has already been implemented somewhere deep in the Rust language.
Except it definitely hasn't.
The reason we're doing this is because we could not convert `Length<Meters>` to `Length<Millimeters>`.
At this point you're likely wondering "what's the issue then?" because the compiler just told us that it didn't have `From` implemented and then when we implement it the compiler says "hold on, I do have an implementation of `From`".

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
I'm not familiar enough with the Rust compiler to say why this is exactly but I'm not the only one to have stumbled across this problem. User Kornel on [http://users.rust-lang.org](http://users.rust-lang.org) posted about this on 16 July 2016 ([https://users.rust-lang.org/t/conflicting-implementations-of-trait-std-convert-from/6427](https://users.rust-lang.org/t/conflicting-implementations-of-trait-std-convert-from/6427)).

So this has been an issue for a while and probably will remain one for the near future.
The question then is can how to achieve compiler assisted conversions to while still avoiding this conflict of `From` implementations.

And as it turns out there is a simple way to do this: with references.
From the compilers perspective `Length<_>` and `&Length<_>` are two completed different things.
This means we can do `impl<'a T1,T2> From<&'a Length<T1> for Length<T2>`!

To do this I'll change the previous `impl From<Length<Millimeters>> for Length<Meters>` to the following.

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

Now our original program works. But it's a bit less clean due to the strange reference needed in the conversion.

```rust
fn main() {
    let l1 = millimeters!(10);
    let l1_meters = f64:from(meters!(&l1));
    println!("l1 = {}", l1);
    println!("l1_meters = {}", l1_meters);

}
```

This bothers me, perhaps more than it should.
But it is definitely an unnecessary thing to ask a user to do.
On top of that, since `Length` implements `Copy` it is counter intuitive for a to reference it for conversions.

To clean this us the conversion macros can be changed to the following.

```rust
macro_rules! meters {
    ($num:expr) => (Length::<Meters>::from(&$num));
}
macro_rules! millimeters {
    ($num:expr) => (Length::<Millimeters>::from(&$num));
}
```

I'm also aware that this action, taking a reference of a 64 bit value that implements `Copy`, is counter productive from the standpoint of CPU operations.
However, I'm trusting that the compiler is smart enough to optimize this away.

More importantly, thought, this has created another problem with the compiler.
Because of the last change calling `meters!(10)` won't compile because there's no code declaring how to go from a `&i64` to `Length<Meters>`.
Fortunately this can be fixed by just adding that implementation into the `ImplFromLengthUnit` macro.

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

And with that all the code is done and all uses of units with lengths can be written as cleanly as possible.


# The final, clean, safe code 

It's been a decent amount of work to get here, but it was well worth the effort.
In just under 200 lines of code[^tokei_count] we have a complete system that allows us to do the following calculations with complete safety and piece of mind with little to no extra runtime cost!

```rust
fn main() {
    let l1 = millimeters!(10);
    let l2 = meters!(5);
    let l3 = (5 * l1) + l2;
    let l3_meters = f64::from(meters!(l3));
    let c1 = circumference(l1);
    println!("l1 = {}", l1);
    println!("l2 = {}", l2);
    println!("l3 = (5 * l1) + l2 = {}", l3);
    println!("l3_meters = {}", l3_meters);
    println!("circumference(radius = {}) = {}", l1, c1);
    println!("l3 > l2 : {}", l3 > l2);
    println!("l3 / l2 = {}", l3 / l2);

    // prints
    // l1 = 10 millimeters
    // l2 = 5 meters
    // l3 = (5 * l1) + l2 = 5050 millimeters
    // l3_meters = 5.05
    // circumference(radius = 10 millimeters) = 62.831853 millimeters
    // l3 > l2 : true
    // l3 / l2 = 1.01
}
```

# Closing thoughts

Rust's type system offers a lot of flexibility to express what you want to achieve with your data.
However, it isn't always obvious how to leverage that type system to represent constraints that are outside the scope software or hardware, such as units of measurement.
I will fully admit that the system I've worked through in this article wasn't obvious when I first created it (it's initial incarnation was for binding unum contexts to values).
I came to use this pattern after feeling frustrated with constant conversions and the unnecessary code that they required.
Hopefully this article will allow others to find a more elegant and safe way to bind contexts of varying units to data and easily move between them without extra code or performance costs.[^performance_size]

The Github repo with the complete example can be found here: [https://github.com/code-ape/rust_length_arithmetic_example](https://github.com/code-ape/rust_length_arithmetic_example).

[^performance_size]: For the record you can use `use std::mem::size_of::Length<Meters>()` to verify that `Length` is in fact only eight bytes in size, meaning we've achieved this system without adding runtime memory cost. Such is the beauty of the Rust compiler.

[^tokei_count]: Exactly 194 lines of code without comments according to [tokei](https://github.com/Aaronepower/tokei).

