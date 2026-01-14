+++
title = "Ethereum development made easy with Foundry"
date = 2022-08-01
slug = "ethereum-development-made-easy-with-foundry"

[extra]
feature_image = "/content/images/2025/12/Jason_and_Medea_-_John_William_Waterhouse.jpg"
authors = ["LambdaClass"]
+++

As part of our trip to Devcon Amsterdam back in April, we attended the War Room Games Amsterdam competition, an Ethereum CTF where you "hacked" smart contracts to win points. The event was loads of fun, but we realized while playing that our main obstacle was not Ethereum/Solidity knowledge, but rather tooling. We knew how to hack most contracts, but struggled to do so because we lacked the right tools, relying a lot on manual Metamask or Remix interaction.

This prompted us to write some [basic REPL-style tool to develop, deploy and interact with smart contracts on chain](https://github.com/lambdaclass/ethereum_war_game_tooling) written in Elixir, a language we are very comfortable with. After writing its basic functionality in a weekend, we started looking for other existing tools not written in Javascript (the most well-known ones, [Truffle](https://trufflesuite.com/) and [Hardhat](https://hardhat.org/), expect you to do everything in JS).

Enter [Foundry](https://github.com/foundry-rs/foundry), an Ethereum toolkit written in Rust. Inspired by [Dapp Tools](https://github.com/dapphub/dapptools), it lets you write, run, test and deploy smart contracts, all in Solidity.

# Ethereum

Before diving into Foundry, a quick recap on Ethereum. As the leading example of blockchain's second generation, Ethereum distinguishes itself most prominently from Bitcoin by running a full [Virtual Machine](https://en.wikipedia.org/wiki/Virtual_machine) capable of (at least in theory) running any computation. This means that it is not just a public ledger for a virtual currency where users can pay each other, but also a global public computer, capable of trustlessly executing any code.

Thus Ethereum transactions are not limited to `eth` exchanges, but can be any arbitrary logic, which allowed the creation of stablecoins, NFTs, DeFi or even [actual games](https://zkga.me/).

For our purposes, you will need to setup an ethereum account, which you can do by downloading an Ethereum wallet like Metamask (the word "wallet" here is a bit of a misnomer, as it allows you to do more than just manage your money). Take note of your account's private key (in Metamask, "Account details" -> "Export Private Key"), as it is will be needed to send transactions to the network.

NOTE: Treat this account you just created as a throwaway to play around. In a real scenario, you should never be copy pasting your private key around, as it is what makes your wallet yours.

# Foundry

Let's now dive into Foundry by going through an example. First, install it with
    
    
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    

## Forge and Cast

Foundry's first and most important tool is `Forge`, a complete testing framework. Let's write a very simple smart contract (taken from [here](https://docs.soliditylang.org/en/v0.8.13/introduction-to-smart-contracts.html)) to see it in action.

## Creating a project

Create a new project with
    
    
    forge init storage
    

This will create a `storage` directory with a bunch of files, the only one we care about for now is in `src/Contract.sol`. Rename that file `Storage.sol` and add the following code to it
    
    
    // SPDX-License-Identifier: UNLICENSED
    pragma solidity ^0.8.13;
    
    contract Storage {
        uint256 number;
    
        function store(uint256 num) public {
            number = num;
        }
    
        function retrieve() public view returns (uint256){
            return number;
        }
    }
    
    

The contract is self-explanatory: it stores a certain number with the `store(num)` method and returns it with `retrieve()`. Running
    
    
    forge build
    

should tell you compilation was successful. We now have our contract compiled, but how do we run it? This is code that's meant to be deployed on the ethereum blockchain, to be interacted with by users who send transactions. Ideally, the tests we perform should be as close as possible to this environment. One thing we can do is deploy it to a Testnet and call it from there.

## Deploying

To deploy a contract to an ethereum network, we can use the `forge create` command. In our case, the easiest way to to interact with a testnet is (unfortunately) to use a provider like [Infura](https://infura.io/) or [Alchemy](https://www.alchemy.com/). Just register with a free account and create a `Goerli` testnet application, which should give you an RPC URL to interact with said testnet that looks something like this
    
    
    https://eth-goerli.g.alchemy.com/v2/<API_KEY>
    

Set the `ETH_RPC_URL` environment variable to this value to use it for all our interactions.

The last thing we need is to fund our account to pay for the transactions we send. For this, look for a faucet like [this one](https://goerlifaucet.com/) and request funds by pasting your address (faucets are a bit annoying in that they're usually either very sketchy or require authentication). Having done all that, let's deploy our `Storage` contract:
    
    
    forge create Storage --private-key <your_private_key>
    

If everything goes well, you should see something like
    
    
    Deployer: <your_address>
    Deployed to: <contract_address>
    Transaction hash: <transaction_hash>
    

## Calling our contract

To interact with our deployed contract, Foundry has a tool called `Cast`; it is a more mature CLI version of the elixir code we wrote mentioned at the beginning.

We can call the `retrieve()` method by doing
    
    
    cast call <contract_address> "retrieve()"
    

which should return
    
    
    0x0000000000000000000000000000000000000000000000000000000000000000
    

Notice the result is in an awkward binary format; that's because it's [ABI](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html) encoded. If we also provide the return type of the method, `cast` will decode it for us:
    
    
    cast call <contract_address> "retrieve()(uint256)"
    0
    

To call the `store` method, we need to use `cast send` instead of `call`. This is because `retrieve` is a method that does not modify any blockchain state, it just reads it. On the other hand, `store` does modify state, which requires sending an actual `transaction` to our contract so that, when it gets included in a block, the `store` method is run and the state of our variable is updated and stored in the network.

All that said, to run `store` we do
    
    
    cast send <contract-address> --private-key <your_private_key> "store(uint256)" 5
    

which, after a while, should return a transacion receipt with all the info about the transaction, and the `number` variable should now be updated to be `5`. We can verify that by running again
    
    
    cast call <contract_address> "retrieve()(uint256)"
    5
    

## Writing tests

We just verified that our contract worked as expected, though it was a bit cumbersome; the problem with trying out smart contracts, as opposed to more traditional development environments, is that most of the code that matters has to go through a transaction on the blockchain. This is a very slow process, so while the above works, it quickly becomes annoying as the code becomes more complex code and starts interacting with other contracts.

Forge allow us to write tests running in a simulated blockchain environment, with the ability to manipulate it to recreate any situation we want.

To keep things simple, we will add a test to the same file we were using before, though typically tests go on separate files. At the bottom of `Storage.sol`, add:
    
    
    import "forge-std/Test.sol";
    
    contract StorageTest is Test {
        Storage storageContract;
    
        function setUp() public {
            storageContract = new Storage();
        }
    
        function testSetWorks() public {
            assertEq(storageContract.retrieve(), 0);
            storageContract.store(5);
            assertEq(storageContract.retrieve(), 5);
        }
    }
    
    

Notice this is just another contract written in solidity, only we imported the `forge-std/Test.sol`, which contains all the test code and utilities, like assertions and logging.

The `setUp` function runs before every test, and in this case just deploys a `Storage` contract so that we can call it. The test itself is in the `testSetWorks()` (test methods must start with the word `test`), and it does the same thing we did above, only in the blockchain environment provided by Forge.

Running `forge test` should print the following
    
    
    Running 1 test for src/Storage.sol:StorageTest
    [PASS] testSetWorks() (gas: 32478)
    Test result: ok. 1 passed; 0 failed; finished in 323.17µs
    

## Printing and events

A very common problem developers new to Ethereum run into is printing variables for debugging. Again, because our code is meant to be run on the Ethereum virtual machine on-chain, printing to standard output isn't something baked into the language. Some people get around it by manually emitting [Events](https://ethereum.org/es/developers/tutorials/logging-events-smart-contracts/), but this is very cumbersome.

The Forge Test contract gives us `console.log` methods to print out values when running tests. If we add a log statement to our test, like so
    
    
    function testSetWorks() public {
        assertEq(storageContract.retrieve(), 0);
        storageContract.store(5);
        uint256 result = storageContract.retrieve();
        assertEq(result, 5);
        console.log(result);
    }
    

and run the tests again with a verbosity of two (`forge test -vv`) we should see
    
    
    Running 1 test for src/Storage.sol:StorageTest
    [PASS] testSetWorks() (gas: 31774)
    Logs:
      5
    

and our variable gets printed. Under the hood, what's happening here is `console.log` emits actual ethereum events (the ones mentioned above) in Forge's execution environment, which Forge are then captured and printed out.

Note that we could have added calls to `console.log` to our regular non-test code, and we would have seen those logs when running tests as well.

## Traces and gas estimation

In the last section we used the `-vv` flag when running tests to show logs, but the verbosity level can go up to five. Running `forge test -vvvvv` should return something like this:
    
    
    Traces:
      [88926] StorageTest::setUp()
        ├─ [34487] → new Storage@"0xce71…c246"
        │   └─ ← 172 bytes of code
        └─ ← ()
    
      [31774] StorageTest::testSetWorks()
        ├─ [2246] Storage::retrieve() [staticcall]
        │   └─ ← 0
        ├─ [20212] Storage::store(5)
        │   └─ ← ()
        ├─ [246] Storage::retrieve() [staticcall]
        │   └─ ← 5
        ├─ [0] console::f5b1bba9(0000000000000000000000000000000000000000000000000000000000000005) [staticcall]
        │   └─ ← ()
        └─ ← ()
    

This shows the stack trace of every test, each function call also showing its associated `gas` cost. Recall `gas` in ethereum is a measure of the cost of execution of a certain operation; the higher it is the more computationally expensive a bunch of code is. Because `gas` is ultimately paid in real money, optimizing it becomes extremely important.

In this case we can see that a call to `store` is an order of magnitude more expensive than `retrieve`, i.e., storing data is much more expensive than just reading it. Additionally, the second call to `retrieve` was 10x cheaper than the first one. This is no bug, the EVM reduces the cost of a storage read if the variable in question has already been read from (i.e. if the variable is `hot`).

## Closing thoughts

Foundry has a lot more features including fuzz testing, forking from live networks, an array of cheatcodes, and the list goes on. For a deeper dive we highly recommend going directly to the [Foundry book](https://book.getfoundry.sh/), it is very easy to follow and has some thorough tutorials.
