+++
title = "Introducing Spawned: Erlang-Style Actors for Rust"
date = 2026-03-31
slug = "introducing-spawned-erlang-style-actors-for-rust"
description = "Check out Spawned, our take on a concurrency framework in Rust inspired by the battle-tested design of the actor model implemented in Erlang in which your business logic is plain Rust methods, no explicit channels, mutexes, or concurrency primitives."

[extra]
feature_image = "/images/2026/Pieter_Bruegel_the_Elder_-_Children---s_Games_-_Google_Art_Project.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Actor Model", "Rust"]
+++

# Introducing Spawned: Erlang-Style Actors for Rust


Section 22.1 of Joe Armstrong's *Programming Erlang* is titled "The Road to the Generic Server", and the author himself calls it the most important section in the entire book. In it, he builds a small server framework — about 15 lines of Erlang — that handles spawning a process, receiving messages, and dispatching them to a callback module. Then he writes a name server on top of it:

```erlang
-module(name_server).
init() -> dict:new().
handle({add, Name, Place}, Dict) -> {ok, dict:store(Name, Place, Dict)};
handle({find, Name}, Dict)       -> {dict:find(Name, Dict), Dict}.
```

That's the entire callback — it creates a dictionary, stores entries, and looks them up. Then Armstrong makes his point:

> Now stop and think. The callback had no code for concurrency, no spawn, no send, no receive, and no register. It is pure sequential code — nothing else. *This means we can write client-server models without understanding anything about the underlying concurrency models.*

Through a series of refactors, he then evolves the server framework — adding fault tolerance, live code upgrades — without touching the callback at all. The business logic stays the same; only the framework changes. This is how Armstrong motivates `gen_server`, the behavior at the heart of OTP that has been running telecom infrastructure since 1998.

[**Spawned**](https://github.com/lambdaclass/spawned) brings this same idea to Rust. It's an actor framework where your business logic is plain Rust methods — no channels, no `Arc<Mutex<T>>`, no concurrency primitives — and the framework handles mailboxes, message routing, and lifecycle.

## A Quick Example

Here's a key-value store — the classic Erlang name server — in Spawned:

```rust
use spawned_concurrency::{protocol, Response};

#[derive(Debug, Clone, PartialEq)]
pub enum FindResult {
    Found { value: String },
    NotFound,
}

#[protocol]
pub trait NameServerProtocol: Send + Sync {
    fn add(&self, key: String, value: String) -> Response<()>;
    fn find(&self, key: String) -> Response<FindResult>;
}
```

That's the entire message interface. `#[protocol]` generates message structs (`Add`, `Find`), a type-erased reference type (`NameServerRef`), and the wiring so any actor that handles these messages can be called through the trait.

The actor implementation:

```rust
use spawned_concurrency::{actor, tasks::{Actor, Context, Handler, ActorStart}};

pub struct NameServer {
    inner: HashMap<String, String>,
}

#[actor(protocol = NameServerProtocol)]
impl NameServer {
    pub fn new() -> Self {
        NameServer { inner: HashMap::new() }
    }

    #[request_handler]
    async fn handle_add(&mut self, msg: Add, _ctx: &Context<Self>) {
        self.inner.insert(msg.key, msg.value);
    }

    #[request_handler]
    async fn handle_find(&mut self, msg: Find, _ctx: &Context<Self>) -> FindResult {
        match self.inner.get(&msg.key) {
            Some(value) => FindResult::Found { value: value.clone() },
            None => FindResult::NotFound,
        }
    }
}
```

And using it:

```rust
let ns = NameServer::new().start();

ns.add("Joe".into(), "At Home".into()).await.unwrap();

let result = ns.find("Joe".into()).await.unwrap();
assert_eq!(result, FindResult::Found { value: "At Home".to_string() });
```

`ns.add(...)` and `ns.find(...)` are regular method calls on the actor reference. Behind the scenes, the macros construct the message, send it through the mailbox, and route the reply back — but none of that leaks into your code.

## Concurrency in Rust Is Hard

Rust gives you the tools to write correct concurrent code. But "correct" and "easy" are not the same thing.

### Shared state

The standard approach to shared mutable state in Rust is `Arc<Mutex<T>>`. It works, but it pushes complexity onto every call site:

```rust
let state = Arc::new(Mutex::new(HashMap::new()));

// Every access: clone the Arc, lock, handle poisoning
let state = state.clone();
tokio::spawn(async move {
    let mut guard = state.lock().unwrap_or_else(|p| p.into_inner());
    guard.insert("key".into(), "value".into());
});
```

This is one lock protecting one `HashMap`. In a real system you have dozens of these, and now you're reasoning about lock ordering, contention, and what happens when a thread panics while holding a lock. The borrow checker prevents data races at compile time, but it can't prevent logical deadlocks, and it can't tell you that your lock granularity is wrong.

### Async complexity

Async Rust solves the throughput problem — thousands of concurrent tasks on a small thread pool — but it introduces its own layer of complexity. Futures are state machines that must be `Send + 'static` to cross task boundaries, which means fighting the borrow checker in new ways. Lifetimes that work fine in synchronous code become errors the moment you add `.await`. `Pin` shows up in trait signatures and confuses newcomers and veterans alike. You get colored functions — async and sync code don't compose easily, and once one layer goes async, it tends to pull everything else with it.

And then there's the runtime dependency. Most async Rust code assumes tokio — but not every project wants or can use tokio. Embedded systems, CLI tools, and codebases with specific threading requirements may need something different.

### The DIY channel approach

The [Actors with Tokio](https://ryhl.io/blog/actors-with-tokio/) pattern is a popular middle ground: give each "actor" a `mpsc` channel, spawn a task that loops over incoming messages, and manage the state inside that loop. It avoids locks, but you end up writing the same scaffolding everywhere — the channel setup, the message enum, the receive loop, the shutdown logic. Every actor is a bespoke piece of infrastructure.

### What actors give you

The actor model sidesteps these problems by making isolation the default. Each actor owns its state, processes messages one at a time, and communicates with other actors exclusively through message passing. There's no shared memory to protect and no locks to order.

Within a handler, your code is sequential — just `&mut self` and the message. This is exactly what Armstrong described: the callback is pure sequential code, and the framework provides the concurrent behavior. In Spawned, the generated dispatch uses the same channel-based architecture you'd build by hand — the macros eliminate the boilerplate, not the performance.

## Why We Built Spawned

There are existing actor frameworks for Rust — notably [Actix](https://actix.rs/) and [Ractor](https://slawlor.github.io/ractor/). We built Spawned because we wanted full control over the framework's features and direction. We also had specific design goals that the existing options didn't fully align with.

**Staying close to Erlang/OTP conventions.** Our team has years of experience building systems in Erlang and Elixir, with a high success rate on those projects. That experience taught us to value the core ideas behind OTP — the separation of business logic from concurrency, the gen_server callback structure, the way protocols define clean interfaces between actors. Spawned's API is modeled directly on `gen_server`: protocols map to module exports, `#[request_handler]` maps to `handle_call`, `#[send_handler]` maps to `handle_cast`, and calling an actor is a method call on a reference — just like calling a client function in an Erlang module.

**A cleaner API surface.** Ractor requires all messages for an actor to live in a single enum, with reply channels embedded as `RpcReplyPort<T>` in each variant. The handler is a single `match` over all variants. Actix avoids this with separate `Handler<M>` impls per message type, but each message still needs a `#[derive(Message)]` and `#[rtype(result = "...")]` annotation. In Spawned, you write a trait with methods and annotate it with `#[protocol]` — the message structs, dispatch logic, and type-erased references are all generated.

**Protocol-level type erasure, not just message-level.** Actix provides `Recipient<M>` — a type-erased reference scoped to a single message type. If your protocol has five methods, you need five separate `Recipient` values. Spawned generates a single `Arc<dyn Protocol>` reference that exposes all methods through one value. Ractor has limited type erasure through `DerivedActorRef`, but it requires each actor to opt in explicitly rather than getting it for free from the framework. The next section shows what this looks like in practice.

**Runtime independence.** All runtime-specific code in Spawned is isolated behind `spawned-rt`, a thin abstraction layer. The current implementation uses tokio, but the architecture is designed so that swapping in a different async runtime, or building a purpose-built one for actor workloads, doesn't require changes to the actor or protocol code.

## Type-Erased Protocol References

Consider a chat application. A room needs to deliver messages to users, and users need to send messages to rooms. With concrete types, this would be a circular dependency between `ChatRoom` and `User`. With protocols, each side depends only on the other's interface:

```rust
#[protocol]
pub trait RoomProtocol: Send + Sync {
    fn say(&self, from: String, text: String) -> Result<(), ActorError>;
    fn add_member(&self, name: String, user: UserRef) -> Result<(), ActorError>;
    fn members(&self) -> Response<Vec<String>>;
}

#[protocol]
pub trait UserProtocol: Send + Sync {
    fn deliver(&self, from: String, text: String) -> Result<(), ActorError>;
    fn say(&self, text: String) -> Result<(), ActorError>;
    fn join_room(&self, room: RoomRef) -> Result<(), ActorError>;
}
```

Notice the return types — this is the distinction between *requests* and *sends*. Methods returning `Response<T>` are requests: the caller sends a message and waits for a reply. Methods returning `Result<(), ActorError>` (or no return type) are sends: fire-and-forget messages that don't block the caller. A single protocol can mix both kinds, and the `#[actor]` macro uses `#[request_handler]` and `#[send_handler]` annotations to generate the right dispatch for each.

`RoomRef` and `UserRef` are automatically generated as `Arc<dyn RoomProtocol>` and `Arc<dyn UserProtocol>`. Actors hold protocol references instead of concrete types:

```rust
pub struct User {
    name: String,
    room: Option<RoomRef>,  // any actor implementing RoomProtocol
}

pub struct ChatRoom {
    members: Vec<(String, UserRef)>,  // any actor implementing UserProtocol
}
```

Neither actor knows the other's concrete type. They communicate purely through protocol interfaces — the same pattern Erlang achieves naturally through PIDs and message passing.

```rust
let room = ChatRoom::new().start();
let alice = User::new("Alice".into()).start();
let bob = User::new("Bob".into()).start();

alice.join_room(room.to_room_ref()).unwrap();
bob.join_room(room.to_room_ref()).unwrap();

alice.say("Hello everyone!".into()).unwrap();
bob.say("Hey Alice!".into()).unwrap();
```

## Async or Threads — Same API, You Choose

Spawned can run actors on an async runtime or on plain OS threads, with the same API.

**Async mode** (`tasks`):
```rust
use spawned_concurrency::tasks::{Actor, Context, Handler, ActorStart};
use spawned_rt::tasks as rt;

fn main() {
    rt::run(async {
        let ns = NameServer::new().start();
        let result = ns.find("Joe".into()).await.unwrap();
    })
}
```

**Thread mode** (`threads`):
```rust
use spawned_concurrency::threads::{Actor, Context, Handler, ActorStart};
use spawned_rt::threads as rt;

fn main() {
    rt::run(|| {
        let ns = NameServer::new().start();
        let result = ns.find("Joe".into()).unwrap();
    })
}
```

The actor implementation is identical in both modes. `Response<T>` is the bridge — in tasks mode you `.await` it, in threads mode you call `.unwrap()` directly.

This matters for concrete reasons:

- A **CLI tool** that spawns actors to parallelize work doesn't need to set up an async runtime — thread mode gives you actors with plain OS threads.
- A **game server** with a fixed-tick main loop can use thread-mode actors for background systems (inventory, matchmaking) without pulling the game loop into async.
- A **CPU-intensive actor** doing compression, proof generation, or physics simulation can run on a dedicated OS thread where the async runtime's scheduler can't interfere — no cooperative yielding, no sharing the thread pool with IO-bound tasks, just uncontested access to a CPU core.

Even within async mode, Spawned lets you choose the execution backend per actor:

- `Backend::Async` — runs on the async task pool (default, best for IO-bound work)
- `Backend::Blocking` — runs on the runtime's blocking thread pool (for CPU-bound handlers that would starve async tasks)
- `Backend::Thread` — runs on a dedicated OS thread (for actors that need thread affinity or real-time guarantees)

## Error Handling and Fault Isolation

When an actor's handler panics, Spawned catches the panic, logs it via `tracing::error!`, and stops the actor. Subsequent messages sent to that actor return `ActorError::ActorStopped`. Other actors in the system are unaffected — the panic is contained to the actor that caused it.

The same applies to lifecycle hooks: if a `#[started]` hook panics, the actor exits immediately without running `#[stopped]`.

The next step on the roadmap is *supervision trees*, which will make recovery declarative and automatic.

## Erlang Developers Will Feel at Home

If you've worked with Erlang/OTP, Spawned's concepts map directly:

| Erlang/OTP | Spawned | Description |
|------------|---------|-------------|
| Module exports (client API) | `#[protocol]` trait | The public message interface |
| `-behaviour(gen_server)` | `#[actor]` | Declare an actor implementation |
| `handle_call/3` | `#[request_handler]` | Sync request handler |
| `handle_cast/2` | `#[send_handler]` | Fire-and-forget handler |
| `init/1` | `#[started]` | Initialization callback |
| `terminate/2` | `#[stopped]` | Cleanup callback |
| `gen_server:call/2` | `ns.find(...)` | Direct method call |
| `gen_server:cast/2` | `ns.notify(...)` | Direct method call (send) |
| `Pid` | `ActorRef<T>` | Handle to a running actor |
| `register/2` | `registry::register(name, ref)` | Register by name |
| `whereis/1` | `registry::whereis(name)` | Look up by name |

## What's Next

- **Supervision trees** — When an actor crashes, who restarts it? Supervision trees make this declarative: you define a tree of actors and a restart strategy (one-for-one, one-for-all, rest-for-one), and the framework handles the rest. This is the feature that makes Erlang systems run for years without downtime, and it's the highest priority item on our roadmap.
- **Observability** — Built-in instrumentation for actor mailboxes, message latency, and lifecycle events, so you can see what your actors are doing in production without adding ad-hoc logging to every handler.
- **Custom runtime** — A purpose-built runtime tailored for actor workloads, replacing the current runtime for teams that want a lighter or more specialized scheduler. The `spawned-rt` abstraction layer is designed to make this swap seamless.
- **Deterministic runtime** — A runtime that produces reproducible execution traces, so you can replay and debug actor interactions exactly as they happened. Inspired by [commonware](https://commonware.xyz).

## Get Started

```
cargo add spawned-concurrency spawned-rt
```

- [GitHub](https://github.com/lambdaclass/spawned)
- [API Guide](https://github.com/lambdaclass/spawned/blob/main/docs/API-GUIDE.md)
- [Examples](https://github.com/lambdaclass/spawned/tree/main/examples)
- [crates.io](https://crates.io/crates/spawned-concurrency)
- [docs.rs](https://docs.rs/spawned-concurrency)

If you have questions or feedback, open an issue on [GitHub](https://github.com/lambdaclass/spawned/issues) or find us on [X](https://x.com/class_lambda).
