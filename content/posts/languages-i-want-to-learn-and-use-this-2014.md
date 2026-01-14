+++
title = "Languages I want to learn and use this 2014"
date = 2014-04-01
slug = "languages-i-want-to-learn-and-use-this-2014"
description = "Take aim much higher than the mark"

[extra]
feature_image = "/images/2025/12/Edward_Burne-Jones.The_last_sleep_of_Arthur.jpg"
authors = ["LambdaClass"]
+++

![](/images/2025/12/1-w6YUSUjzOr5yeXXUggaEIg.png)

#### Take aim much higher than the mark

* * *

> A wise man ought always to follow the paths beaten by great men, and to imitate those who have been supreme, so that if his ability does not equal theirs, at least it will savor of it. **Let him act like the clever archers who** , designing to hit the mark which yet appears too far distant, and knowing the limits to which the strength of their bow attains, **take aim much higher than the mark** , not to reach by their strength or arrow to so great a height, but **to be able with the aid of so high an aim to hit the mark they wish to reach.** —**_Niccolo_ _Machiavelli_**

And that’s the excuse I have to explain why I want to learn so many languages on this 2014.

* * *

### Lisp, Common Lisp and Clojure

Immediately after reading [Beating the Averages](http://paulgraham.com/avg.html) from Paul Graham I wanted to learn Lisp:

> By induction, the only programmers in a position to see all the differences in power between the various languages are those who understand the most powerful one. (This is probably what Eric Raymond meant about Lisp making you a better programmer.) You can’t trust the opinions of the others, because of the Blub paradox: they’re satisfied with whatever language they happen to use, because it dictates the way they think about programs.

However, I didn’t have enough time to do it. At that moment I was coding a lot in Ruby, Python, C++ and Java in order to earn enough to live by my own.

![](/images/max/2000/1-uDtazbx2QjY_M5c2iu-gNQ.jpeg)

Now that I am a better paid code monkey and that I have enough free time, I am reading [The Land Of Lisp](http://landoflisp.com/). As I dive down into the rabbit hole of the Lisp world, I am trying to create my own emacs distribution called [Lunfardo](https://github.com/pyotrgalois/lunfardo). I think it’s a good way to learn Emacs and Lisp. I hope to finish reading the book and the [Lisp Koans](https://github.com/google/lisp-koans) in the following weeks.

A few weeks ago I read some chapters from **Seven Concurrency Models in Seven Weeks** by Paul Butcher. The chapter **The Clojure Way — Separating Identity from State** got my attention. After reading it, I investigated [core.async](https://github.com/clojure/core.async) and its [channels](http://clojure.com/blog/2013/06/28/clojure-core-async-channels.html). It appears that, as in many great languages, there are [many flavors of concurrency in Clojure](http://adambard.com/blog/clojure-concurrency-smorgasbord/).

Then I watched [Persistent Data Structures and Managed References](http://www.infoq.com/presentations/Value-Identity-State-Rich-Hickey) by Rich Hickey, author of Clojure. Since I am interested in concurrency-related things and in Lisp, Clojure seems like a good next stop in my roadmap. So I added [Clojure for the Brave and True](http://http//www.braveclojure.com/) to the list of books I have to read in the next few weeks. As I read it I hope to play with [Clojure Koans](https://github.com/functional-koans/clojure-koans).

However, as most developers, I think that the best way to learn a language is to use it in a real project. Therefore, I will try to implement a few ideas I got in Clojure.

![](/images/max/2000/1-PyX6M9lSBXLHvVgAlDXrTA.png)

* * *

### Haskell

![](/images/max/2000/1-mIrYVuSZtaYe3WJkRwUqwQ.jpeg)

The most important reason why I want to learn Haskell is that two of the most inteligent persons I know really love it -and that’s a good enough reason for me. After checking [Learn X in Y minutes Where X=haskell](http://learnxinyminutes.com/docs/haskell/), the syntax seems quite simple. I have read complaints about it. At this moment I really can’t see why. I will have to learn it before having a strong opinion.

This video from Brian Beckman caught my attention: [Don’t fear the Monad](https://www.youtube.com/watch?v=ZhuHCtR3xq8). Even if monads are not unique to Haskell, they are really important for this language since it’s a pure language:

> Haskell functions are in general pure functions: when given the same arguments, they return the same results. The reason for this paradigm is that pure functions are much easier to debug and to prove correct. Test cases can also be set up much more easily, since we can be sure that nothing other than the arguments will influence a function’s result. We also require pure functions not to have side effects other than returning a value: a pure function must be self-contained, and cannot open a network connection, write a file or do anything other than producing its result. This allows the Haskell compiler to optimise the code very aggressively.  
> However, there are very useful functions that cannot be pure: an input function, say getLine, will return different results every time it is called; indeed, that’s the point of an input function, since an input function returning always the same result would be pointless. Output operations have side effects, such as creating files or printing strings on the terminal: this is also a violation of purity, because the function is no longer self-contained.  
> Unwilling to drop the purity of standard functions, but unable to do without impure ones, Haskell places the latter ones in the IO monad. In other words, what we up to now have called “IO actions” are just values in the IO monad.

I have never used a really pure programming language. It’s time to check it out and weigh its benefits.

![](/images/max/2000/1-3IMSBVSph3XTwJEidHh0tw.png)

[@mrb_bk](https://twitter.com/mrb_bk):

> Think of typechecking the same way you think of testing or even linting — an analysis phase that can help you gain confidence

> Once you grasp the deep connections that “propositions as types” has to offer, you’ll get hooked and long for correctness

> Proper modern languages will have modern type checkers that can seamlessly analyze programs and aid in annotation.

I am also interested in using a language with a strong typesystem that adds something. In Java, C++ and similar languages I feel like that I have to add a lot of information to my code without having a real benefit. That’s why I prefer to use Javascript, Python or Ruby. From what I have read Haskell’s typesystem is really usefull.

At last, some years ago I played with [xmonad](http://xmonad.org/), a tiling window manager. You configure it using Haskell. For the last 4 or 5 years I have used its main competitor called awesome (configured with Lua). I want to learn Haskell to understand and use xmonad.

* * *

### Erlang, Elixir and LFE

For the last 6 months I have been working as an Erlang developer. At this moment I am coding a messaging server for [Whisper](http://whisper.sh/) using ElasticSearch for storing the messages and Cowboy to create the webserver endpoints.

I really like Erlang, even if I think its ecosystem leaves a lot of room for improvement. I am not a big fan of its Prolog based syntax. I don’t think it’s complex or difficult but the use of comma ‘**,’** , semicolon ‘**;’** and period **‘.’** as terminators is cumbersome (you need to change the terminator almost every time you move a line) and doesn’t have any real benefit:

[The excitement of Elixir](http://devintorr.es/blog/2013/01/22/the-excitement-of-elixir/):

> Erlang’s syntax does away with nested statement terminators and instead uses expression separators everywhere. Lisp suffers the same problem, but Erlang doesn’t have the interesting properties of a completely uniform syntax and powerful macro system to redeem itself.

It is not a real problem anyway. If you follow one of the three ways to read Erlang code explained on the post called [On Erlang’s Syntax](http://ferd.ca/on-erlang-s-syntax.html), you will get it really fast. In general, I agree with [Erlang syntax again … and again … and again …](http://rvirding.blogspot.com/2014/01/erlang-syntax-again-and-again-and-again.html):

> While I can understand people may dislike the syntax of a certain language, even I dislike some syntaxes, I don’t understand people who say “I was going to learn Erlang but the syntax was so strange I quit”.

If you know that there are really awesome areas where [Erlang BLOOMS](http://ferd.ca/rtb-where-erlang-blooms.html), you will learn the language even if it’s different from your main language.

> My point is that the syntax is the easy part of learning a new language, just look it up in the manual. It is learning the semantics of the new language and how to use it efficiently to solve your problems which are the major difficulties. How do I structure my solution to best make use of the language and its environment? This is where major rethinks will occur. This is what takes time to learn and understand. Not in what it looks like.

I want to use Elixir on a daily basis not only because I think it has a better syntax:

[Elixir: It’s Not About Syntax](http://devintorr.es/blog/2013/06/11/elixir-its-not-about-syntax/):

> The great thing about the Elixir standard library is that with each release it can provide features that Erlang developers clamor for everyday. We have Erlangers, Clojurists, Haskellers, Rubyists, and Pythonistas trying to incorporate useful features into Elixir every day. Elixir isn’t afraid of introducing functionality that improves the lives of Elixir developers, and everything is on the table: new data structures, real Unicode support, anything.

> […]

> Elixir isn’t the CoffeeScript of Erlang just as Clojure isn’t the CoffeeScript of Java. Just like Clojure, Elixir is more than a pretty face. Elixir is the power of it’s tooling, the expressiveness of it’s metaprogrammability, and the expansive feature set of it’s standard library while maintaining complete compatibility with—and heavily leveraging—OTP. Once again I have yet to adequately scratch the surface of what makes Elixir special, but I have more Elixir to write!

I have only played with Elixir for a few hours before learning and really using Erlang. I plan to use [Dynamo](https://github.com/dynamo/dynamo) and [Ecto](https://github.com/elixir-lang/ecto) instead of using Nodejs with Express or Erlang with Cowboy to create my next REST system. I will let you know if I find a real benefit of using it instead of Erlang.

At last I wanted to mention my latest discover: Lisp Flavored Erlang (LFE)

> Nothing Quite Compares to the taste of Erlang, aged in the oaken barrels of Lisp, served at a temperature of perfect hotness.

![](/images/max/2000/1-Zv2If-7X5lPmvj_BAtOVIw.png)

I think this doesn’t need any more clarification. After learning Lisp I will give LFE a try. Check out its [awesome guide](http://lfe.github.io/user-guide/intro/1.html).

### R programming language

A few months ago I bought a book called **Exploring Everyday Things with R and Ruby**. I saw its table of contents and I knew I wanted to read it.

> If you’re curious about how things work, this fun and intriguing guide will help you find real answers to everyday problems. By using fundamental math and doing simple programming with the Ruby and R languages, you’ll learn how to model a problem and work toward a solution.

> Here are some of the questions you’ll explore:

> \- Determine how many restroom stalls can accommodate an office with 70 employees

> \- Mine your email to understand your particular emailing habits

> \- Use simple audio and video recording devices to calculate your heart rate

> \- Create an artificial society—and analyze its behavioral patterns to learn how specific factors affect our real society

I bet now you want to read it too. But that’s not all. A guy that I really respect, called Zed Shaw, wrote [Programmers Need To Learn Statistics Or I Will Kill Them All](http://zedshaw.com/essays/programmer_stats.html). At the end of the post he encourages you to learn R. I only know basics of statistics, so I will try to kill two birds with one stone:

> Learning to use R will help you also learn statistics better.

![](/images/max/2000/1-SgUML3Hsk6MNGH3uvn7VRw.png)

A few weeks ago I started a course on coursera about [Machine Learning](https://www.coursera.org/course/ml). Apparently, R is also very useful if you are into Machine Learning. There also an interesting book from O’Reilly called **Machine Learning for hackers** that uses R. Check them if you are interested.

![](/images/max/2000/1-ULb9lkajm38eGIfrtRX7ZQ.png)

* * *

As you can see I have a lot to learn this year. I hope I could inspire you to learn some of these language!
