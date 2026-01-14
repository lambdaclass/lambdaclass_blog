+++
title = "Sonic: a minimalist  alternative to Elasticsearch written in Rust"
date = 2019-04-02
slug = "sonic-a-minimalist-alternative-to-elasticsearch-written-in-rust"
description = "Database implementation sits in a nice spot between computer science and software engineering. There are lot of tradeoffs to consider…"

[extra]
feature_image = "/content/images/2025/12/Repin_Comune.jpeg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Elasticsearch", "Rust"]
+++

![](/content/images/max/2000/1-ur9rT3EUiunAzys52MePnQ.jpeg)« Sonic » is the mascot of the Sonic project. Valerian drew it to look like a psychedelic hipster hedgehog.

Database implementation sits in a nice spot between computer science and software engineering. There are lot of tradeoffs to consider. That is why nowadays we have a plethora of databases, each of them useful in a particular scenario. In the projects we work on at [LambdaClass](https://lambdaclass.com/) we always end up using the following: Redis, Elasticsearch, PostgreSQL, Kafka and Riak or Cassandra. It is difficult to keep up with the number of databases that are needed and it is even more difficult to learn about their internals.

I always end up using Elasticsearch to index documents, to generate autocompletes and for geolocation. [Sonic](https://github.com/valeriansaliou/sonic) doesn’t solve all three problems but it is a good tool to solve the first two. I have not yet used it in production, but it seems like a good lightweight alternative to Elasticsearch.

Since we love databases and we are trying to focus on Rust projects, [Amin Arria](http://twitter.com/nenearria) and I decided to interview Sonic’s creator, [Valerian Saliou,](https://github.com/valeriansaliou) who generously agreed. Also remember to check Sonic’s [repository](https://github.com/valeriansaliou/sonic).

* * *

**What is Sonic?**

Sonic is an open-source search index server, written in Rust. It was built with simplicity, performance and lightweight-ness in mind. Sonic takes user queries in, and return identifiers. Those identifiers refer to actual documents in a relational database (eg. in our case: messages, helpdesk articles, CRM contacts, etc). Sonic does not store documents, which makes the whole system simple and efficient regarding storage, as an application getting search results from Sonic has to pull actual result data from another database (eg. MongoDB, MySQL, etc. given the search results IDs that are returned).

**Don’t Solr, ElasticSearch, Tantivy and Toshi solve similar issues to Sonic? Why did you create a new alternative?**

I run a business called Crisp, which provides 100,000 users with a customer support software. Users want to search in their messages, and some of our users have A LOT of messages. Using traditional open-source search index softwares (eg. Elasticsearch amongst others) proved to be too expensive for our freemium model, as those systems are heavy and thus require huge server CPU and RAM.

As a developer and sysadmin, I really love Redis for its simplicity and speed. In computer software, simplicity often provides speed, which is a good thing at scale. I built Sonic to be “the Redis of search”: simple features, simple network protocol.

**Why did you decide to use Rust? How was the experience of creating Sonic in Rust?**

Rust makes the whole development experience smoother. The constraints of the language (eg. the borrow checker, the fact that there are no NULL values) guarantee that you won’t experience certain kinds of bugs while running your project in production (eg. NULL pointer exceptions and segmentation faults, which are unavoidable in programming languages such as C, C++ or Go; humans make mistakes).

I’ve already built other Rust projects in the past to support the Crisp infrastructure at scale, such as Bloom, Vigil and Constellation (which are also available as open-source software on my GitHub). Rust was no new thing to me; overall I love working with the language. My first Rust projects 2 years ago were a bit rough, as you have to spend a lot of time with the borrow checker getting in your way for “no reason”. Once you understand how it works, you become much more productive and Rust borrow checker errors become rare.

So overall, I can say that the experience of writing Sonic in Rust has been great. I love Rust. As a plus, it makes me become a better programmer.

**What is Sonic Channel? Is this feature inspired by Redis?**

Sonic Channel is the name of the protocol used to communicate with Sonic over the network. As most application infrastructures today are distributed over multiple machines via the network, a TCP-based protocol to push new text data to the index and query the index was required. For performance reasons, I did not want to write an HTTP-based protocol, as Elasticsearch has.

After releasing Sonic, I got a lot of contributions from the community to build Sonic Channel libraries (integrations) for the most popular programming languages: Go, Python, Ruby, Java, PHP and JavaScript (runs on NodeJS only). This let developers push data and search for items in Sonic right from their application, in their preferred programming language. It makes the whole process of integrating Sonic easier that calling a REST API, and cleaner.

**What data structures do you use to create the index and to autocomplete words?**

The index is stored in a LSM (Log-Structured Merge-tree), which is used by RocksDB under the hood. To auto-complete words, Sonic uses an FST (Finite-State Transducer), which is explained in great details in an article by [BurntSushi](https://github.com/BurntSushi) on [his blog](https://blog.burntsushi.net/transducers/a).

An FST is stored on-disk for each Sonic (collection, bucket) pair, and is memory-mapped, which means that actual FST data is not loaded in RAM, but access is still fast. The downside of the Rust FST implementation that I’m using, is that any built FST is immutable. If a new word appears in a Sonic bucket, it needs to be pushed to the FST and thus a new FST needs to be re-built. Sonic runs a consolidation task periodically for mutated FSTs, and adds or remove words from them on-disk.

The FST structure is not only used for word auto-completion, but also for typo corrections (eg. it is capable of correcting “Englich” to “English”). It uses a Levenshtein automaton to achieve that (given a maximum Levenshtein distance that’s relative to the length of the word; ie. the longer a word is, the more typos you allow).

**Why did you choose RocksDB as the storage?**

[RocksDB](https://github.com/facebook/rocksdb) (from Facebook) is built on LevelDB (from Google), which I had good experience using through the SSDB open-source software.

It is very good at keeping performance stable on huge key-spaces and minimizes disk usage by compressing old data (it has a leveled data storage architecture, where old data gets in lower levels, that can be compressed or compressed with a higher but slower ratio).

RocksDB improves on LevelDB, and is very configurable. This means Sonic users can tune the internals of RocksDB through Sonic configuration to get the best out of their setups given their server hardware (spinning disks or SSDs, how many CPU cores they have, etc.).

**Any material you can offer for anyone wanting to learn how a search engine like Sonic works, and how to build it?**

I’ve written a blog post summing up quickly [how Sonic works](https://journal.valeriansaliou.name/announcing-sonic-a-super-light-alternative-to-elasticsearch/). I plan to write an extensive documentation to explain the inner workings on Sonic, which is tracked on [this GitHub issue](https://github.com/valeriansaliou/sonic/issues/103).

Overall, reading Sonic code should help understand how things work. I spent a lot of time commenting my code and making it as clear as possible.

**What is jemalloc and why do you use it?**

jemalloc is a memory allocator that has been originally written for FreeBSD. It was designed for modern CPU architectures, and is much better at managing memory on multi-core architectures. It has no benefits on single core architectures though, but has been proved to be as good as older allocators in the case of single-CPU. So at worst it’s as good as traditional allocators, at best it provides better performance on multi-core CPUs and reduced memory fragmentation.

Rust previously used jemalloc as its default allocator, and has recently moved to the system allocator for reasons other than performance. People can [read more on jemalloc](https://www.bsdcan.org/2006/papers/jemalloc.pdf).

**Did you have any experience building something like this before? What do you recommend reading to other people to learn how to build a tool like Sonic?**

I’ve built a great deal of server software, but I’ve never written databases. Databases can be hard, as they involve a great deal of lock strategies to prevent race conditions, so database developers have to be meticulous. Locks are hard to get right; locks in production are even harder: it’s easy to write code that dead-locks, while finding why a dead-lock occur is painful.

I’d recommend people willing to build a Sonic-like project to read existing source code. The best way to build things yourself it to understand how others did it in the past.

**Do you think they are fine? Do you want to change anything?**

Yes, looks like Sonic worked great so far. Crisp search is now snappy and our results are relevant. Our users are happy.

Our Sonic instance indexes half a billion objects (messages, articles, contacts). The compressed index is 20GB, and CPU usage under load is 10% of 1 Intel Xeon core. Sonic uses ~200MB of RAM for such a large index at worst, and 20MB when it’s cold-started. Search latency is under 1ms.
