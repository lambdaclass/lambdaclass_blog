+++
title = "The eleventh year: what to do after having taught yourself programming in ten years"
date = 2015-01-11
slug = "the-eleventh-year-what-to-do-after-having-taught-yourself-programming-in-ten-years"
description = "You have followed the “Teach Yourself Programming in Ten Years” advice. Now what?"

[extra]
feature_image = "/content/images/2025/12/Poussin_-_Paysage_avec_saint_Jean_a--_Patmos_-_Chicago_Art_Institute.jpg"
authors = ["LambdaClass"]
+++

![](/content/images/2025/12/1-ITiI4UpZDr3uVhpAqtmzIw.png)

You have followed the “[Teach Yourself Programming in Ten Years](http://norvig.com/21-days.html)” advice. Now what?

* * *

![](/content/images/max/2000/1-oNMoLW1PYnEIcHQaHkDD_w.jpeg)__“when you don’t create things, you become defined by your tastes rather than ability. your tastes only narrow & exclude people. so create.”―__****Why The Lucky  Stiff****

Christmas and the new year’s eve have passed. Now you are a few kilograms fatter. You have spent the last few days reading Hacker News and Reddit and playing League of Legends or GTA V for the PS4. Finally, even if you will never accomplish all of them, you know that it is time to write your goals for this new year.

After working for more than a decade in IT as a [programmer and sysadmin](http://blog.codinghorror.com/vampires-programmers-versus-werewolves-sysadmins/) I know that I am nothing more than an [average](http://www.paulgraham.com/avg.html) developer or [novice](http://zedshaw.com/archive/the-master-the-expert-the-programmer/) that knows a little bit of many things. After developing for quite some time in C, C++, Ruby, Python and Javascript I wanted to move on to something else. I was bored. Thankfully, working with Erlang for a year and a half introduced me to the amazing world of functional programming, distributed systems, parallalelism and concurrency, and there is no way of going back. [Erlang also led me to the Haskell and Lisp/Clojure](/languages-i-want-to-learn-and-use-this-2014/) world. I found Haskell, with its awesome [Parsec](http://book.realworldhaskell.org/read/using-parsec.html) parser combinator library, at the bottom of the rabbit hole of compilers and programming language design. Finally, Lisp was the selling point that made me migrate from vim to emacs.

In this post I try to to share my goals of this year for myself, so that I can check them next year to measure the outcame of 2015. I really hope that you can find an interesting link or at least that it encourages you to write your 2015 goals so that next year you can check how much improvement you have made!

### **Cleaning up my closet**

#### gut

First of all I need to finish my project [gut](https://github.com/unbalancedparentheses/gut) (pronounced ‘goot’, short for ‘gutenberg’). gut is a template printing, aka scaffolding, tool for Erlang. It is like rails generate or yeoman. I have created it because in my last job I did something that most Erlang developers that I know don’t do very often: creating projects from scratch. Erlang applications have many setup files: rebar.config, Makefile, erlang.mk, project.app.src, rel/sys.config, config/vm.args and tipically a project_app.erl and project_sup.erl. Creating this every time you need to create a new project for a new customer is pretty boring and overwhelming if you are a newcomer. So I created gut, a tool that uses project generators to instantiate a new project. Generators can be created by any user, and I do not need to add them to gut: anybody can use them since gut fetches them from github.

rebar3, the latest Erlang build tool, has a similar concept called [template](http://www.rebar3.org/v1.0/docs/using-templates). I was not aware of this when I created gut. I will try to change gut so that gut generators are fully compatible with rebar3 templates. In some way, rebar3 templates solve the same problem that gut does. However, gut can automatically download on demand any generator/template available in github to instantiate a new project.

#### tinyerl

[tinyerl](https://github.com/unbalancedparentheses/tinyerl) is a really small project to show how easy it is to create a URL shortener service in Erlang using different HTTP servers such as cowboy, axiom, elli and leptus. It is meant to teach Erlang. I only need to polish it a little bit and update [Become an Erlang Cowboy and tame the Wild Wild Web — Part I](https://medium.com/erlang-lisp-and-haskell/become-an-erlang-cowboy-and-tame-the-wild-wild-web-part-i-37f8dd1df160) before writing Part II which will be based on tinyerl.

#### lunfardo

Like most devs, I have tested and used many IDEs: Eclipse, Netbeans, Xcode, Visual Studio, IntelliJ IDEA, RubyMine, PyCharm, Code::Blocks, Aptana. Nevertheless, for the last few years I could never move away from the combination of a good shell like [fish](http://fishshell.com/) with a good configuration like [oh my fish](https://github.com/bpinto/oh-my-fish), a customized vim based on [spf13](http://vim.spf13.com/) distribution, and the simple but great [dwm](http://dwm.suckless.org/) [tiling window manager](https://en.wikipedia.org/wiki/Tiling_window_manager).

After reading [The Nature of Lisp](http://www.defmacro.org/ramblings/lisp.html) I have been interested in using Lisp but I never invested enough time to really play with it. After watching a coworker use Emacs and a few good ruby minor modes, I started using Emacs and its Elisp. Emacs is like a mini operating system. It has a package manager, the best [git client](https://github.com/magit/magit) I have used, great modes like paredit…

swank-js for editing Javascript…

and undo-tree for treating history as tree.

![](/content/images/max/2000/1-xcDvxVvdrTYMR_WMunTlqw.png)

This video shows really well how easy it is to hack with Emacs and lisp:

The only issue I had with Emacs is that I like modal editing á la Vi. Hopefully, Emacs has a great mode called [evil](https://bling.github.io/blog/2013/10/27/emacs-as-my-leader-vim-survival-guide/) that transforms Emacs into the best Vim editor after Vim.

Inspired by bbatsov’s [Prelude](https://github.com/bbatsov/prelude) distribution, I coded my own distribution called [lunfardo](https://github.com/unbalancedparentheses/lunfardo). It’s still in alpha stage. I am not yet a great Elisp coder and I keep on adding and removing modes and shortcuts. I have not yet commited the code for managing most of the programming languages I use (Python, Ruby, Javascript, Erlang, C, Haskell).

I am already used to all the Emacs shortcuts but I don’t really like them. So I am changing most of them into more modern ones. The final objective is to use Emacs as the platform, with defaults shortcuts based on [Sublime](http://www.sublimetext.com/) and with a shortcut to quickly toggle on and off vim modal editing. We will see how it works out, I am quite excited about it but I am not completely sure that it is possible to easily change everthing I want in Emacs (specially some shorcuts). So I wouldn’t recommend to test lunfardo yet since it will break very often, but I am pretty sure you can find a few cool ideas and modes.

#### Spawned Shelter

Finally, this year I started acollection of the best articles, videos and presentations related to Erlang called [Spawned Shelter](https://github.com/unbalancedparentheses/spawnedshelter). I wanted to create a static web page like [Superhero.js](http://superherojs.com/) for Erlang but I have been way to busy. I am pretty sad since I could not do it yet. Before the end of this year I am completely sure that it will be finished.

### Distributed systems

Using Erlang, Apache [Cassandra](http://planetcassandra.org/what-is-apache-cassandra/) and [Zookeeper](http://highscalability.com/zookeeper-reliable-scalable-distributed-coordination-system) in my last project was the final step I needed to take to be fully interested by distributed systems. I can not be more thankfull to my previous employer ([Inaka](http://inaka.net/) and [Erlang Solutions](https://www.erlang-solutions.com/)) for giving me the oportunity to work with those tools and to learn from great teammates and our CTO [Brujo](https://github.com/elbrujohalcon).

[Distributed systems for fun and profit](http://book.mixu.net/distsys/) mini book was the best place for me to start reading about this topic. Christopher Meiklejohn’s [reading list](http://christophermeiklejohn.com/distributed/systems/2013/07/12/readings-in-distributed-systems.html) also seems very good but isn’t a good place to start without knowing a few things before.

Finally, Aphyr’s [posts](https://aphyr.com/tags/Jepsen) and talks are also an excellent place where to learn from:

After reading about and playing with [Riak](http://basho.com/riak/), I have already decided that in the next work project where I need to use a distributed database or a key-value store I will give it a try. In the process of reading about Riak, I found [Riak Core](https://github.com/basho/riak_core), a toolkit for building distributed, scalable, fault-tolerant applications. Before giving it a try I want to implement something like [try-try-try](https://github.com/rzezeski/try-try-try).

Next I want to implement Plan9 [venti](https://medium.com/@jlouis666/eventi-ffd423d82b35), a network storage system were a hash of the data acts as its address, using riak and Erlang. It won’t be very different from [Jesper L. Andersen](https://medium.com/@jlouis666/)’s [code](https://github.com/jlouis/eventi), but my objective is to learn, not to create something new.

I hope I will have some spare time to play with the following list of interesting Erlang libraries: [fuse](https://github.com/jlouis/fuse), [safetyvalve](https://github.com/jlouis/safetyvalve), [dispcount](https://github.com/ferd/dispcount), [worker_pool](https://github.com/inaka/worker_pool), [epocxy](https://github.com/duomark/epocxy), [pobox](https://github.com/ferd/pobox), and to read the latest book from [Fred Hébert](http://ferd.ca/):

[Stuff Goes Bad: Erlang in AngerThis book intends to be a little guide about how to be the Erlang medic in a time of war. It is first and foremost a…www.erlang-in-anger.com![](https://cdn-images-1.medium.com/fit/c/160/160/0*nevqmTdZyE2QPpJN.)](http://www.erlang-in-anger.com/)

### Programming Languages

After going through the [Programming Languages](https://www.coursera.org/course/proglang) and [Compilers](https://www.coursera.org/course/compilers) Coursera courses I become more interested by programming language design and implementation. Then I started experimenting with and reading about [lexical analysis](https://en.wikipedia.org/wiki/Lexical_analysis), [parser generators](https://en.wikipedia.org/wiki/Compiler-compiler), [BNF grammar](http://www.garshol.priv.no/download/text/bnf.html), [context free grammar](http://trevorjim.com/how-to-prove-that-a-programming-language-is-context-free/), [LL and LALR](http://blog.reverberate.org/2013/07/ll-and-lr-parsing-demystified.html) parsing, [flex and bison](http://gnuu.org/2009/09/18/writing-your-own-toy-compiler/), [lemon](http://www.hwaci.com/sw/lemon/lemon.html), [antlr](http://www.antlr.org/), [ragel](http://www.colm.net/open-source/ragel/), [bnfc](http://bnfc.digitalgrammars.com/), [rpython](http://morepypy.blogspot.it/2011/04/tutorial-writing-interpreter-with-pypy.html), [hyperglot](https://tmcnab.github.io/Hyperglot/) and how [parsing is the weakest link in software security](http://trevorjim.com/parsing-is-the-weakest-link/)!

After reading all that, I needed to get my hands dirty so I followed [Build Your Own Lisp](http://www.buildyourownlisp.com/contents) and [Create Your Own Programming Language](http://createyourproglang.com/). In the process I got really interested by the simplicity of [Parsec](http://plataforma10.com/login) and [PEG parsers](http://fdik.org/pyPEG/) (saddly they have some important [limitations](https://stackoverflow.com/questions/1857022/limitations-of-peg-grammar-parser-generators)). Its worth mentioning that I found Parsec while reading the mind-blowing book [Real World Haskell](http://book.realworldhaskell.org/read/). You should check [learnhaskell](https://github.com/bitemyapp/learnhaskell) and [intro_to_parsing](https://github.com/JakeWheat/intro_to_parsing) if you are interested by Haskell and Parsec.

One of my goals for this year is to start writing my own programming language using [Haskell and LLVM](http://www.stephendiehl.com/llvm/). Before that I am doing something easier: [Write Yourself a Scheme in 48 Hours](https://en.wikibooks.org/wiki/Write_Yourself_a_Scheme_in_48_Hours), which also uses Haskell. Obviously, I am not trying to create the next programming language. That might even be impossible until programming language design is [done based on more real evidence](https://medium.com/@jlouis666/proglang-design-with-evidence-1444213f3902).

Someday I hope that I can implement an Erlang clone that runs on the [really](http://jlouisramblings.blogspot.com.ar/2013/10/embrace-copying.html) [awesome](http://jlouisramblings.blogspot.com.ar/2013/01/how-erlang-does-scheduling.html) BEAM VM, but that uses indentation á la Python as a way to delimit blocks of code instead of “**,** ”**,** “**;** ” and “.”. It would be a sort of exact copy of Erlang but without its Prolog terminators. Apparently this has [already](http://farmdev.com/thoughts/47/making-erlang-indentation-sensitive/) [been](http://ulf.wiger.net/weblog/2008/03/19/indentation-sensitive-erlang/) [done](http://ulf.wiger.net/weblog/2008/03/20/indentation-sensitive-erlang-2/) by Ulf Wiger but I would like to do it with [leex and yecc](http://relops.com/blog/2014/01/13/leex_and_yecc/), the lex and yacc of the Erlang toolset, which are used for example by [luerl](https://github.com/rvirding/luerl) and [lfe](https://github.com/rvirding/lfe). Mariano Guerra has implemented a [toy language](https://github.com/marianoguerra/match), which is incredible useful for learning purposes, using leex and yecc before implementing efene, a programming language with C-like syntax that runs on the Erlang platform.

Since I am noob in this area and I like to share what I learn I will continue interviewing language developers and good devs for my [Indie Programming Languages](https://medium.com/indie-programming-languages) collection. I will publish two interviews in the following weeks. In the meanwhile you can read:

[Indie languages — Interview with Timothy Baldridge, Pixie’s language creatorPlease tell us a little bit about Pixie’s inception and the road to the current status I’ve been a language hacker for…medium.com![](/content/images/fit/c/160/160/1-jYqNf1VQpmxhv7WwkPm1Ag.jpeg)](https://medium.com/p/cadbc36418dc)

### Do you need a cool project?

I won’t be able to do it this year, but I hope that next year I will be able to go through Linux From Scratch’s [guide](http://www.linuxfromscratch.org/lfs/) and the [little book about OS development](https://littleosbook.github.io/) to scratch the surface of how operating systems work.

### This is the end, my only friend, the end

As you have read, in my free time I am not trying to code anything groundbreaking. For the moment I am only interested in exploring how things work.

Even if this is not your eleventh year in the world of development and you are pretty new, I cannot stress enough how much functional programming will open your mind. At least in my case it has been a mind-blowing experience since it has opened me the hell’s gate of distributed systems and programming languages implementation and design. Someday it might be time to return to the old and powerful C, but not yet…

![](/content/images/max/2000/1-zIUcPGRK3us1N3oFwJ8y5w.jpeg)
