---
layout: post
title: Functional Java for parallel processing
---

The modern software engineer faces a set of problems that did not exist 15 years ago. Looking at the advancement of processing power in recent years signals the end of Moore's Law. The clock speeds of modern processors seem to be plateauing and the only way to make things go faster is to add more processing cores. With the ever-increasing need to process more and more data, our software architectures need to adapt in order unlock the full potential of the hardware.

Almost all computer programs have to store some kind of state in order to be useful. However, state is the enemy of concurrent processing. There has been a resurgence in the popularity of functional programming in recent years. This trend is largely driven by the need to take advantage of multi-core processors. In a functional paradigm the result of a unit of work is only dependent on its input and not dependent on any external state. Let's look at the classic example of calculating the *nth* Fibonacci number in Java:

{% highlight java linenos %}
public int fibonacci(int n) {
    if(n == 1) {
        return 0;
    } else if(n == 2) {
        return 1;
    } else {
        return fibonacci(n - 1) + fibonacci(n - 2);
    }
}
{% endhighlight %}

The return value of this function is not dependent on any state that is external to the function. In fact, this function does not store any state whatsoever (note how there are no assignment statements). In order to achieve a completely stateless function, this implementation uses [*recursion*](https://en.wikipedia.org/wiki/Recursion_%28computer_science%29), meaning that the function calls itself within the function body.

Recursion is a technique that is used frequently in the functional paradigm. Some functional languages like [Haskell](https://www.haskell.org/) do not even have looping constructs and rely wholly on recursion to implement loops. The main advantage of recursion is that it eliminates the need for maintaining state during loops but as a downside it has a negative effect on the amount of RAM required. Thankfully, RAM is extremely cheap in this day and age.

A slightly more stateful implementation of the Fibonacci function is as follows:

{% highlight java linenos %}
public int fibonacci(int n) {
    if (n == 1){
        return 0;
    } else if (n == 2){
        return 1;
    }

    int n_minus2 = 0;
    int n_minus1 = 1;
    int n;

    for (int i = 3; i <= n; i++){

        n = n_minus2 + n_minus1;
        n_minus2 = n_minus1;
        n_minus1 = n;

    }

    return n;
}
{% endhighlight %}

In this implementation the state of variables `n_minus2`, `n_minus1` and `n` is kept and therefore recursion is not necessary. From a system-boundary perspective this implementation still meets some of the requirements of a functional paradigm such as the fact that the return value is only dependent on the input and not on any *external* state.

By eliminating dependence on external state, many of these fibonacci calculations can be done in parallel across multiple different processors and still produce the correct results. This allows us to use these types of functions with event-driven architectures to aid in parallelization.

I frequently use an event-driven framework called [vert.x](http://vertx.io) in my own developments. This framework supports both the classic publish-subscribe pattern and also a point-to-point messaging pattern where an event is only consumed by a single handler.

Stay tuned for a blog post explaining the basics of event processing in vert.x.

**UPDATE:**

After publishing this post a friend of mine, [Rijnard van Tonder](https://www.linkedin.com/in/rijnard), made some good comments about whether or not my code examples are truly stateless.

The point is that even though there are no assignment statements in the function body itself, this does not mean that there is no state being kept. The function is given a function argument (an initial state) and a value is returned (another state). His conclusion is that the function is in fact stateful but that the state is implicit.

These are his exact words:

> Some thoughts on this. Your pure recursive version of fibonacci isn't "completely stateless"--it very much keeps state of what's going on. On an abstract level, recursive calls can be realized with a stack data structure representing each "iteration" state. Most of the time, this stack can be omitted in the case of tail-recursion. In your case, there are no explicit local variables (well, there's n), but that does not mean that there's no state: for instance, you supply your function with an initial state (n) and receive your fibonacci number back (another state). So perhaps the correct wording here is to say that the state is *implicit*.
>
> Functional programming styles tend to favor making state implicit "until you need something explicitly". If this idea interests you, I recommend you read up on continuation-passing style for fun (just as a taster). CPS breaks away from traditional imperative programming by removing the need for "return" statements.
