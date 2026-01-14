+++
title = "The Wisdom of Iroh"
date = 2025-04-09
slug = "the-wisdom-of-iroh"
description = "We interview the team developing Iroh, a Rust peer-to-peer library that just works. "

[extra]
feature_image = "/images/2025/12/Carl_Blechen_-_Waldweg_bei_Spandau_-_Google_Art_Project.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Distributed Systems", "Distributed Computing"]
+++

As we’ve written before, most of us at Lambda are internet natives. The formative experiences that made us who we are include meeting people on the other side of the world through IRC, sharing knowledge, media, and code via BitTorrent, wikipedia, and software version control systems, the birth of the first search engines, and the feeling that _everything_  was accessible. We then grew up and found frustration that this experience did not yet extend to the financial tasks needed to be an adult, and that terms like _walled garden_  better described the new state of our internet home.

This is why we get a double high when learning about projects like Iroh: an emotional tug from a project that enables building distributed systems in a way that gives users more agency, and a nerdy thrill from the technical challenges they’ve solved to achieve it.

## What is it?

[Iroh](https://www.iroh.computer/) is a distributed systems toolkit, focused on easily setting up reliable p2p connections. It includes facilities for establishing direct connections, moving data, syncing state, and pluggable application-level protocols. It’s working in production and has managed 200k concurrent connections and millions of devices on the same network with low service costs.

In their own words:

> Iroh is a library for establishing the most direct QUIC connection possible between two devices. Every _endpoint_  uses the public half of a cryptographic keypair to identify itself. Assuming at least one configured _relay server_  is reachable, an endpoint keeps exactly one TCP connection to a “home relay” that other nodes use for connection establishment, and as a fallback transport. Iroh uses a suite of _discovery services_  to resolve home relays & endpoint IDs. Connections between endpoints use QUIC ALPNs to distinguish between _protocols_ , while _routers_  automate the endpoint accept loop for protocol multiplexing.

One of the things we like about Iroh is that it is clear on what it is about. It runs on QUIC, started out as a new implementation of IPFS, went through several iterations, and reduced its scope to better solve the problems they were facing. They wrote about this process in their [Smaller is Better](https://www.iroh.computer/blog/smaller-is-better) and [Roadmap](https://www.iroh.computer/blog/road-to-1-0) posts, and we fully agree that this is good engineering practice.

## What can Iroh be used for?

[`n0`](https://n0.computer/), the company behind Iroh, keeps a [list](https://github.com/n0-computer/awesome-iroh) of projects building on them but to get a quick idea, it can be of use in anything that needs file sync, p2p game streaming, distributed object storage, peer discoverability and swarm membership, local-first design, or compute job orchestration.

One of our partners, [Nous Research](https://github.com/nousresearch) is using it in a decentralized program which relies on iroh to manage communications between nodes training LLMs, sending messages between the clients to advance the state of the network and share the gradients calculated by each node.

Today, we interviewed the team to get some insight.

### _1\. Many of the n0 team members are ex-IPFS or libp2p developers. One of the first questions asked is how Iroh compares to libp2p and as we understand it, the answer is related to having a tighter focus, keeping the core about making p2p connections that just work, and moving the rest to application-level protocols such as iroh-gossip, -blobs and -docs that can be mixed and matched as desired. Can you elaborate on this process and how reducing scope helped?_

b5: The process was one of slowly divesting ourselves of a lot of "p2p project baggage". Most p2p projects end up defaulting into a boil-the-ocean stance where they try to ship one of everything: a DHT, transports, pubsub, RPC, and over time we've come to believe this is a big contributing factor to p2p projects feeling like half-baked prototypes. It clicked for us when our CTO dig pointed out "no one wants the nginx team to ship postgres". A DHT is a huge undertaking, reliable sync is a huge undertaking, reliable transports are a huge undertaking. Sometime last year we realized it just wouldn't be possible to ship all this stuff with the team we had, so we picked the transport layer, and are focused on integrating with other projects & the community forming near iroh for the things we can't ship. Our bet is things will work better if a project like [loro](https://loro.dev) ships [optional iroh support](https://github.com/loro-dev/iroh-loro), the loro team makes a truly robust CRDT, and we make a truly robust transport. There's pressure on both teams to make the public APIs small & composable, to make integration easier.  
A lot of this is testament to just how incredible a technical feat `libp2p` is, especially when you see the sheer number of language implementations, it's truly impressive. But that amount of work comes with a big API surface area, makes it very challenging to port all of that functionality into a robust package that works well on a phone. It also creates the expectation that `libp2p` maintainers commit to delivering both a robust DHT _and_ a reliable transport. When we more focus we explicitly mean fewer features that both work more consistently & are integrated across organizations.

### 2\. How did the decision to use QUIC come about? A few months ago some [research](https://dl.acm.org/doi/10.1145/3589334.3645323) indicated QUIC might have some downsides and there seems to be anecdotal evidence of hostility to the new protocol from network engineers. Does your team have opinions wrt to any aspect of this? Are there any indications for Iroh adopters that might stem from QUIC usage?

b5: the goals of QUIC closely resemble what we're trying to do with iroh: ship new capabilities on the internet *with software*  because changing the hardware is impractical. QUIC is trying to tackle protocol ossification that set in because routers can inspect TCP headers, and doing that by dropping down to the UDP layer & working from there. Along with being aligned at "spiritual" level, things like QUIC multipath support seem almost designed for our exact use case. It's a young technology that we're all-in on.  
   
I haven't heard much in the way of hostility from network engineers, but I'm not entirely surprised. QUIC is intentionally trying to reduce the visible surface area to routers & internet middleboxes, which I'm sure would be frustrating. I happen to be of the mind that internet middle boxes shouldn't be messing with those packets in the first place, but hey, that's just me 😄

### 3\. You’ve mentioned that Iroh has seen a million devices on the same network. Is this in relation to the public Iroh relays or in another context? What are the scalability limits you’ve seen and in which scenarios?

The biggest numbers we've seen have come from app developers deploying iroh as part of an update to an existing app. Each of those has stressed iroh in different ways. We've shipped against those stress tests for the last 6 months. It's by no means done, but it is giving us in-production feedback that's critical as we work toward our 1.0 release later this year.

### 4\. Iroh-gossip is particularly interesting as a modern implementation of HyParView and Plumtree. What made you choose these protocols? Have you done load tests on this protocol in particular? What is your approach to testing and load testing in general?

b5: phones. If we're going to make p2p work on a mobile devices, "star" topologies that compensate for high network churn with lots of connections simply aren't viable, which makes the active/passive divide in PlumTree particularly appealing. As I'm writing this someone in our discord is running a [2000 node iroh gossip stress test](https://discord.com/channels/1161119546170687619/1161119546644627528/1357726363657834788) using an erlang supervisor, so yes, it's being tested! We also have a battery of smoke & simulation tests that run against the iroh gossip protocol as part of CI.  
Gossip has been getting more attention lately, which is driving us to put more time into it. Frando from our team has been actively working on stability as we speak.

### 5\. You encourage users to set up their own relays for their networks but are also very generous with the three public ones you offer. Aside from avoiding the rate limits, why use private relays? Are there any security or other feature considerations?

b5: It's totally fine to use the public relays! Honestly, we'd love to see more use so we can stress them more :). As a gentle reminder for everyone: relay traffic is e2ee, so the relays can't see traffic, but relays _do_ have a list of nodeIDs, and list of connections they're facilitating, which is privileged information. Many of our more serious users are using private relays to avoid exposing that information to the public, or even to number 0, which is things working as intended in our view. We have some plans in the works for a complimentary service that will make spinning up relays very easy. Stay tuned for that!

### 6\. When developing distributed systems, observability becomes a prime concern. [Iroh-doctor](https://www.iroh.computer/blog/iroh-0-16-a-better-client#iroh-doctor-plot) seems like a cool tool to have. Does Iroh offer other facilities for observing and debugging its internals or the application? What role does Iroh-metrics play in this?

b5: We're actively working on this. Gathering actionable network metrics in a p2p system is critical as we make p2p a mature, reliable thing. We'll have way more to say on this one in the coming months.

### 7\. P2P systems usually disclose the IP addresses of the participating nodes and Iroh explicitly chooss to give applications flexibility in what (if anything) to do in this regard. What choices do you see are usually taken, and what mechanisms (aside from VPNs) can applications implement?

b5: I should clarify that any connection within iroh will _always_ end up exposing your IP address to the peer that you're dialing, and the relay server your node uses as it's home. This is also true of _so_ many services you use every day, so iroh isn't new in this regard. With that said, yeah a VPN is rarely a bad idea, and we expicitly run one-off tests between n0 staff where we start a big file transfer & switch VPN on & off during transfer to confirm it works (spoiler: it does).  
The implications of connecting users will be different for each application, but we generally ask folks to use their heads: if your app is 5-100 person invite-only chat rooms, then it makes sense to couple iroh connections with room memberships. If your app is, say, twitter, then you might need to introduce a new opt-in mechanism that makes it clear to the user that you're disclosing something that might be abused.

### 8\. The local-first software movement (prioritizing user data being stored and processed on their own devices rather than relying on cloud servers) is new and slowly gaining traction. Do you see Iroh being used in this context or are most of the main users focused on other use cases?

b5: YES. we <3 local first in a big way, and think p2p is the only way to get to software that is both local first and networked. The thing user agency, p2p, and local first all have in common is shipping more capabilities to the end-user's device than we traditionally get with today's "view layer on an API" apps.

### 9\. Coupling Iroh with a CRDT such as [automerge](https://automerge.org/) seems to be a common pattern. Iroh-docs seems geared to be a distributed KV store but is based on range-based set reconciliation. Do you see these higher-level usage patterns being codified as other protocols? Are there other protocols in development, or do you see any particular pattern as a likely future protocol?

b5: yes, iroh + automerge is definitely "using iroh as intended", and you get at a good point: there are common patterns like message bootstrapping, incremental updates, and pairwise reconciliation that are commmon across a bunch of these protocols. To be able to actually have those protocols share abstractions for these patterns we'd need a more robust story for protcol composition than we currently have, because we'd need a way for a protocol to express dependencies & do protocol version matching across the set of registered protocols at compilation time. Even then, it would require the buy-in from projects like automerge, which really isn't a goal of ours right now.  
I think it's going to take years, but I do think we'll get to a place where we declare a dependency graph of protocols, the compiler will be able to tell you if you have a version mismatch, and we'll be able to further decompose these patterns as a community. I'm doing some experiments in this direction on the side, but don't expect to see anything in this department before we cut iroh 1.0.

### 10\. You’ve [written](https://www.iroh.computer/blog/async-rust-challenges-in-iroh) about the challenges of using async rust and we can certainly relate! In our experience Greenspun’s tenth rule applies transmuted to distributed systems (sometimes called Virding’s rule) “Any sufficiently complicated concurrent program in another language contains an ad hoc informally-specified bug-ridden slow implementation of half of Erlang.” What is your experience with the actor and message passing approach, both in Rust when implementing Iroh and more generally when using Iroh to build systems that communicate?

b5: lol yes very much to the half-Erlang. We're very much in that uncanny valley right now with iroh. Most of the internal guts are implemented with actors, but we haven't formalized that into an actor abstraction, and it's unclear that we ever will. Where that pain is felt more accutely is at the protocol level. At the level of protocol developement, it would be very nice to have easy-to-implement patterns that abstract around distibuted fault tolerance & give you that "fail whenever you want" characteristic the supervisor trees bring. The protocol dev is also at the right height in the stack, dealing with logical messages instead of raw packets.  
We're still working on the groundwork of getting tutorials in place for writing a protocol in the first place, but I'd love to see us spend more time cooking up recipes for protcol development atop an actor model abstraction.

###   
11\. Your [roadmap](https://www.iroh.computer/roadmap) is quite clear, webassembly support being oft-requested and recently merged, and better support on the way for clients wanting to use Iroh in browsers without having to send all data over relays. Some notable items in the more distant roadmap are a spec and FFI integrations. Can you elaborate on their importance and/or motivation? Do you have an estimate on when 1.0 is due and any comments on what motivates the upcoming features? What are you most excited about?

b5: The spec part is fun because iroh can be pretty easily expressed as a composition of existing specs, which is our plan. In our view 1.0 means you know clearly what the thing is, and how it _should_ behave, so why not write that down in a spec? That said, we're far more concerned with working software than a spec, and see taking the time to write out a spec as a means of confirming we've considered everything we need to as part of a 1.0 push, and can communicate that consideration clearly. As for FFI bindings, we _really_ , _really_ want to get to languages outside of rust, but have a lot of work to do here. More on FFI in the July-August time range. Current plan for 1.0 is sometime in September.  
As for excitement, Divma & Floris on our team have been hard at work on support for QUIC multipath for _months_. It's a huge undertaking, and we're all very excited to see it come together.  

### 12\. Are there any bindings or plans for bindings to other languages? Iroh-ffi seems to provide support for Python, what is it’s status and do you plan to offer official support for any other languages?

b5: Yes, we have plans, but need to figure out some hard stuff around what basically amounts to duck-typing in UniFFI bindings first :)  

Many thanks to the Iroh team for taking the time to answer our questions!

References  
• <https://www.iroh.computer/proto/iroh-gossip>  
• <https://www.bartoszsypytkowski.com/hyparview>  
• <https://asc.di.fct.unl.pt/~jleitao/pdf/dsn07-leitao.pdf>  
• <https://www.bartoszsypytkowski.com/plumtree/>  
• <https://asc.di.fct.unl.pt/~jleitao/pdf/srds07-leitao.pdf>  
• <https://www.iroh.computer/proto/iroh-docs>  
• <https://www.iroh.computer/proto/iroh-blobs>

![](https://ssl.gstatic.com/ui/v1/icons/mail/images/cleardot.gif)
