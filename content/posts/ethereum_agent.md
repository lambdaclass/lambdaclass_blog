+++
title = "Ethereum Agent: a typescript SDK designed for agents to operate autonomously in Ethereum"
date = 2026-01-23
description = "To address the architectural gaps in existing Ethereum libraries for autonomous AI agents, we built eth-agent, a typescript SDK designed from first principles for autonomous Ethereum interaction, with safety constraints that are fundamental to the execution model."

[taxonomies]
tags = ["ethereum", "AI"]

[extra]
authors = ["LambdaClass"]
feature_image = "/images/2026/Napoleon_at_the_Battle_of_Rivoli.jpg"
math = false
+++

[Ethereum](https://blog.lambdaclass.com/ethereum-is-the-new-financial-backend-of-the-world/) emerged as a general purpose financial backend reducing the cost and complexity of building financial services while improving their speed and security. For decades the internet accelerated communication but did not create a neutral system for defining ownership or enforcing obligations. Ethereum solves these problems by embedding them in software with economic and cryptographic guarantees. Originally, the infrastructure was designed to be operated by humans. The rise of AI introduced agents as tools that assist humans on performing tasks. As AI agents transition to act autonomously, their interaction with financial infrastructure demands a rethinking of the interface design. Most Ethereum libraries were designed for human developers who then review transactions before signing. These offer no guarantees against modes of failure that are unique to autonomous operations.

To address this architectural gaps, we built [eth-agent](https://github.com/lambdaclass/eth-agent), a typescript SDK designed from first principles for autonomous Ethereum interaction, with safety constraints that are not optional middleware but fundamental to the execution model.

![Stablecoins](/static/images/2026/eth_agent_stablecoins.png)

This is part of a larger endeavour to help Ethereum become the backbone of the modern financial systems. We are building [ethrex](https://github.com/lambdaclass/ethrex) (a minimalistic performant Ethereum execution client written in Rust, that can also be used as L2 client and that is built from scratch as a ZK native client), [ethlambda](https://github.com/lambdaclass/ethlambda) (a consensus client for Lean Ethereum), lambda-vm with [Aligned](https://alignedlayer.com/) (a zero-knowledge virtual machine that will allow us to prove correctness of the execution of ethrex in the framework of Lean Ethereum), [lambdaworks](https://github.com/lambdaclass/lambdaworks) and now [eth-agent](https://github.com/lambdaclass/eth-agent).

## The institutional gap

Ethereum provides what the internet lacked: a neutral system for defining ownership and enforcing obligations—a shared ledger with a programmable execution environment, and cryptographic enforcement. New financial services gain immediate scale because they can rely on infrastructure that is permissionless and runs 24/7. However, Ethereum assumes competent users. It assumes whoever signs a transaction intended to sign it. It assumes the caller understood what he was approving. These assumptions held when humans operated the infrastructure directly (and even so, there have been several big mistakes by human operators). They break when AI agents operate on behalf of humans.

The agent might hallucinate an address. It might misunderstand "send 100" as 100 ETH rather than 100 dollars. It might be manipulated through prompt injection. It might handle decimals incorrectly and send a million times the intended amount. Each failure mode is individually unlikely. Collectively, over millions of agent operations, they become certainties. And unlike traditional finance, there is no recourse. No bank to call. No transaction to reverse. No dispute to file. The funds are simply gone.

## The problem with existing libraries

Existing Ethereum libraries (such as ethers.js, viem, web3.js) were built for human developers who review transactions before signing. They offer no protection against the failure modes unique to autonomous operation.

Consider what happens when an AI agent uses ethers.js to send a transaction:

```typescript
const wallet = new ethers.Wallet(privateKey, provider);
const tx = await wallet.sendTransaction({
  to: ensName,
  value: parseEther(amount)
});
```

This code has no concept of spending limits. No mechanism for human approval. It produces errors like `UNPREDICTABLE_GAS_LIMIT` or hex encoded revert data that an LLM cannot interpret meaningfully. The library assumes a human is in the loop. When there isn't one, failure is silent or catastrophic. The problem is that it was designed for a different threat model. We need libraries that assume the caller might be an unreliable reasoning system operating at scale.

## Two approaches to agent safety

The industry has produced two responses to this problem.

The first approach builds tools for humans to supervise agents. Dashboards, approval queues, audit logs. The human remains in the loop, reviewing agent proposals before execution. This preserves safety but sacrifices the primary advantage of agents: scale. If every transaction requires human review, you have an expensive way to generate transaction proposals, not an autonomous system.

The second approach builds guardrails—runtime checks that reject dangerous operations. Spending limits, allowlists, sanity checks. This allows autonomous operation within boundaries. But guardrails are just more code, and code has bugs.

eth-agent takes the second approach, with an important difference: we minimize the trusted surface area to a small, auditable constraints engine rather than spreading safety checks across a large codebase. The constraints engine is the only code that must be correct. Everything else can fail without catastrophic consequences.

## Design principles

eth-agent is built on three principles:

### 1. Safety constraints are not optional

Every wallet instance carries spending limits that cannot be bypassed by the calling code. A transaction that would exceed the daily limit fails with a structured error, regardless of what the agent requests:

```typescript
const wallet = AgentWallet.create({
  limits: {
    perTransaction: '0.1 ETH',
    perHour: '1 ETH',
    perDay: '5 ETH',
  },
});
```

This is not a suggestion. An agent cannot import a different module or modify configuration to circumvent these limits. The safety boundary is in the library, not the application.

### 2. Errors are structured for machine consumption

Every exception carries machine readable metadata:

```json
{
  "code": "DAILY_LIMIT_EXCEEDED",
  "message": "Transaction would exceed daily limit",
  "suggestion": "Reduce amount to 2.5 ETH or wait until 2024-01-16T00:00:00Z",
  "retryable": true,
  "retryAfter": 14400000,
  "details": {
    "requested": { "eth": "5" },
    "remaining": { "eth": "2.5" }
  }
}
```

An agent can programmatically determine whether to retry, how long to wait, and how to explain the failure to a user. This is the difference between `catch (e) { throw e }` and `catch (e) { return scheduledRetry(e.retryAfter) }`.

### 3. Human oversight is architecturally supported

For high-value operations, the library supports approval callbacks that halt execution until a human responds:

```typescript
const wallet = AgentWallet.create({
  onApprovalRequired: async (request) => {
    return await askHuman(request.summary);
  },
  approvalConfig: {
    requireApprovalWhen: {
      amountExceeds: '0.1 ETH',
      recipientIsNew: true,
    },
  },
});
```

This is not a webhook you add later. The approval flow is part of the transaction lifecycle, and the agent receives a structured denial if approval is withheld.

## How constraints prevent failures

Consider the failure modes mentioned earlier. Each requires a specific defense.

**Hallucinated addresses.** An agent might generate a plausible but incorrect address. eth-agent provides two defenses: a blocklist that rejects known malicious addresses, and an allowlist mode that restricts transfers to preapproved recipients only. In allowlist mode, an agent cannot send to any address not explicitly authorized by the human who configured the wallet.

**Amount confusion.** An agent might interpret "send 100" as 100 ETH when the user meant 100 dollars, or mishandle token decimals. eth-agent's stablecoin helpers parse amounts as the token's native units. For example, `amount: '100'` means 100 USDC, not 100 x 10^6 raw units. For ETH, amounts require explicit units: `'0.1 ETH'` or `'100 GWEI'`. The parser rejects ambiguous amounts.

**Prompt injection.** An attacker might craft input that instructs the agent to drain the wallet. eth-agent's constraints engine does not see prompts. It only sees proposed transactions. No instruction can override the limits. If the daily limit is 1 ETH, the agent cannot send 2 ETH regardless of what text appears in its context window.

**Repeated small transactions.** An agent might drain a wallet through many small sends that individually seem reasonable. eth-agent maintains rolling windows of spending history. The hourly limit aggregates all transactions in the past hour; the daily limit aggregates the past 24 hours. A thousand 0.001 ETH transactions hit the limit just as a single 1 ETH transaction would.

**Runaway spending.** An agent in a loop might exhaust the entire balance before anyone notices. The emergency stop triggers when spending exceeds a percentage of the initial balance (configurable, default 50%). The minimum balance protection ensures a reserve is never touched. Both constraints halt all operations until a human intervenes.

These are not features. They are constraints. The value is in what they prevent.

## Stablecoins as first-class citizens

Autonomous agents handling payments need stablecoins, not volatile assets. eth-agent provides built-in support for USDC, USDT, USDS (Sky), DAI, PYUSD, and FRAX with human-readable amounts:

```typescript
import { AgentWallet, USDC } from '@lambdaclass/eth-agent';

// Send 100 USDC (not 100 * 10^6)
await wallet.sendUSDC({ to: 'merchant.eth', amount: '100' });

// Multi-chain support built-in
const balance = await wallet.getStablecoinBalance(USDC);
console.log(balance.formatted);  // "1,234.56"
```

Decimal handling is automatic (USDC uses 6 decimals, USDS uses 18) and addresses are resolved per-chain. An agent can request `sendUSDC({ amount: '100' })` without understanding token decimals or looking up contract addresses. This is the kind of abstraction that prevents expensive mistakes.

## ERC-4337 and account abstraction

eth-agent includes first-class support for smart accounts (ERC-4337), bundlers, and paymasters:

```typescript
const smartAccount = await SmartAccount.create({
  owner: EOA.fromPrivateKey(key),
  rpc,
  bundler,
});

await smartAccount.execute([
  { to: addr1, value: ETH(0.1), data: '0x' },
  { to: addr2, value: ETH(0.2), data: '0x' },
]);
```

Session keys enable delegated signing with limited permissions—an agent can be granted authority to sign transactions up to 0.1 ETH for one hour, to specific contract addresses, with a maximum transaction count. When the session expires or limits are reached, signing fails cleanly.

## Minimal dependencies

eth-agent depends on exactly two runtime packages:

- `@noble/secp256k1` — ECDSA operations
- `@noble/hashes` — Keccak256, SHA256

Both are audited, maintained by [@paulmillr](https://paulmillr.com/noble/), and contain no transitive dependencies. We do not depend on ethers.js, viem, or web3.js. The core cryptographic primitives, such as RLP encoding, ABI encoding, transaction signing, are implemented directly.

This is a deliberate choice. Dependency bloat is a security liability, and autonomous systems should minimize their attack surface.

## Comparison with existing approaches

Several frameworks enable AI agents to interact with blockchains. They differ in what they optimize for.

Coinbase AgentKit optimizes for breadth. It provides dozens of actions covering token transfers, swaps, NFT operations, and contract deployment. It integrates deeply with Coinbase infrastructure, including Smart Wallet for key management and gasless transactions through paymasters. The implicit model is an agent that needs to do many different things, with safety delegated to the Coinbase platform layer.

GOAT SDK optimizes for DeFi composability. It provides over 200 integrations connecting agents to lending protocols, AMMs, yield aggregators, and prediction markets across 30+ blockchains. The implicit model is an agent executing complex financial strategies, with safety delegated to the human who configured the strategy.

eth-agent optimizes for safety guarantees. It provides fewer actions (basic transfers, token operations, balance queries) but each action is constrained by limits that cannot be bypassed. The implicit model is an agent that must not cause catastrophic harm, even if it malfunctions. eth-agent will also add DeFi composability and more applications, but with a security first guarantees.

### Design philosophy

| Aspect | eth-agent | Coinbase AgentKit | GOAT SDK |
|--------|-----------|-------------------|----------|
| Primary optimization | Safety | Action breadth | DeFi composability |
| Agent model | Constrained operator | General assistant | DeFi executor |
| Safety philosophy | Architectural constraints | Platform delegation | User configuration |
| Vendor coupling | None | Coinbase ecosystem | None |

### Safety constraints

The following table shows constraints that eth-agent provides as built-in, architectural properties of the execution path. These constraint categories reflect what we believe agent safety requires. Other frameworks may approach safety differently, such as through platform-level controls, wallet provider features, or application-level implementation.

| Constraint | eth-agent | Coinbase AgentKit | GOAT SDK |
|-----------|-----------|-------------------|----------|
| Per-transaction limits | Built-in | Application-level | Application-level |
| Rolling hourly limits | Built-in | Application-level | Application-level |
| Rolling daily limits | Built-in | Application-level | Application-level |
| Rolling weekly limits | Built-in | Application-level | Application-level |
| Stablecoin-specific limits | Built-in | Application-level | Application-level |
| Gas spending limits | Built-in | Application-level | Application-level |
| Emergency stop (% threshold) | Built-in | Application-level | Application-level |
| Minimum balance protection | Built-in | Application-level | Application-level |
| Address blocklist | Built-in | Application-level | Application-level |
| Address allowlist | Built-in | Application-level | Application-level |
| Human approval flows | Built-in | Application-level | Application-level |
| Transaction simulation | Built-in | Via CDP | Via provider |

"Application-level" means the framework does not include this constraint, but a developer could implement it in their application code. The difference is whether safety is a property of the framework or a responsibility of each application.

### Supported operations

| Operation | eth-agent | Coinbase AgentKit | GOAT SDK |
|-----------|-----------|-------------------|----------|
| ETH transfers | Yes | Yes | Yes |
| ERC-20 transfers | Yes | Yes | Yes |
| Stablecoin helpers | Multi-chain | Yes | Yes |
| ENS resolution | Automatic | Yes | Yes |
| Token swaps | Yes | Yes | Yes |
| NFT operations | Soon | Yes | Yes |
| Contract deployment | Soon | Yes | — |
| Yield/lending | Soon | — | Yes |
| Prediction markets | Soon | — | Yes |
| Social integrations | Soon | Farcaster | — |

eth-agent intentionally excludes complex DeFi operations. Each additional operation type is additional surface area for errors. For agents that need swaps or yield strategies, eth-agent can be combined with other frameworks. For example, use eth-agent for constrained value transfers, another framework for DeFi execution.

### Infrastructure

| Feature | eth-agent | Coinbase AgentKit | GOAT SDK |
|---------|-----------|-------------------|----------|
| Smart accounts (ERC-4337) | Yes | Yes | Yes |
| Session keys | Yes | Yes | Via wallet provider |
| Gasless transactions | Via paymaster | Via CDP | Via provider |
| Multi-chain support | EVM chains | EVM + Solana | 30+ chains |
| Passkey authentication | Yes | Yes | Via wallet provider |

### AI framework support

| Framework | eth-agent | Coinbase AgentKit | GOAT SDK |
|-----------|-----------|-------------------|----------|
| Anthropic Claude | Native | Via adapters | Native |
| OpenAI | Native | Native | Native |
| LangChain | Native | Native | Native |
| Vercel AI SDK | — | Native | Native |
| MCP (Model Context Protocol) | Native | Native | — |

## Framework integrations

Adapters for OpenAI, Anthropic, and LangChain transform wallet operations into function definitions these frameworks can invoke:

```typescript
import Anthropic from '@anthropic-ai/sdk';
import { anthropicTools } from '@lambdaclass/eth-agent/anthropic';

const tools = anthropicTools(wallet);

const response = await anthropic.messages.create({
  model: 'claude-sonnet-4-20250514',
  tools: tools.definitions,
  messages: [{ role: 'user', content: 'Send 0.01 ETH to vitalik.eth' }],
});
```

The tools expose `get_balance`, `send_transaction`, `preview_transaction`, and related operations. Safety limits apply regardless of which framework invokes them.

## The execution layer thesis

AI agents will improve. They will hallucinate less, understand context better, resist manipulation more effectively. But they will never be perfect. Any system that relies on agent correctness will eventually fail, and in financial contexts, failure means permanent loss.

The solution is not to make agents smarter. The solution is to make the execution layer impossible to misuse.

```
┌─────────────────────────────────────────┐
│              AI Agent                   │
│  (imperfect, improving, fallible)       │
└──────────────────┬──────────────────────┘
                   │ proposes action
                   ▼
┌─────────────────────────────────────────┐
│     Constrained Execution Layer         │
│  (bounded, deterministic, auditable)    │
└──────────────────┬──────────────────────┘
                   │ only valid actions pass
                   ▼
┌─────────────────────────────────────────┐
│        Irreversible Settlement          │
└─────────────────────────────────────────┘
```

The agent can propose any action. The execution layer filters. Only actions satisfying all constraints reach the blockchain. The agent remains useful, creative, flexible. The execution layer remains safe, bounded, predictable.

This is analogous to how operating systems handle untrusted code. The kernel does not trust that applications will behave correctly. It enforces memory isolation, permission checks, resource limits. Applications can be buggy or malicious, but the system remains stable because the kernel constraints are architectural, not policy.

eth-agent applies this principle to financial operations. The agent is untrusted code. The wallet is the kernel. The constraints are architectural.

## Toward formal verification

The current implementation enforces constraints through runtime checks. This is better than no constraints, but the constraints engine is still code that could have bugs. We are exploring formal verification using Lean to make the safety guarantees mathematical rather than empirical, a proof that "spending cannot exceed X per day" rather than a claim about it.

This does not verify the agent. The agent remains unverified, unpredictable, capable of proposing anything. What gets verified is the filter—the execution layer that stands between agent proposals and blockchain settlement.

## Conclusion

Ethereum provides the financial infrastructure the internet lacked. AI agents provide operators that can use that infrastructure at scale. The missing piece was an execution layer designed for agents as operators, not as intermediaries between humans and blockchains, but as the ones actually executing transactions, with all the constraints that implies.

eth-agent provides this layer. Not by making agents smarter, but by making the system safe regardless of how agents behave. The constraints are not suggestions. They are structural properties of the execution path.

The agent proposes. The system disposes. Only safe actions reach the chain.
