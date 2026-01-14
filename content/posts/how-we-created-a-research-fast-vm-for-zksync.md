+++
title = "How we created a research fast VM for ZKsync"
date = 2024-08-05
slug = "how-we-created-a-research-fast-vm-for-zksync"

[extra]
feature_image = "/images/2025/12/Horace_Vernet_-_The_Vesuvius_Erupting-_the_Artist_and_His_Father-_Carle_Vernet-_in_the_Foreground_-_2014.254_-_Museum_of_Fine_Arts.jpg"
authors = ["LambdaClass"]
+++

For the past few weeks we have been working on a reimplementation of ZKsync's (out of circuit) EraVM. The goal is to improve on its current performance and explore the possibility of adding parallel execution through BlockSTM. For that, we first had to make a deep dive into how the EraVM works and how it differs from the EVM.

We want to thank Anthony Rose and the Matter Labs team for all their help on this project, especially their [new fastVM implementation](https://github.com/matter-labs/vm2) which we used a lot as a reference.

You can follow our progress on [our EraVM repository](https://github.com/lambdaclass/era_vm).

## Development Process

It's important to state our methodology: even though the main goal here is improving performance, our goal starting out is different: we want a simple implementation working.

We do not care about benchmarks **at first**. We know our initial implementation will be slow, but that's not the point: the point is to get something simple working to understand all the moving parts. Only after that's in place we shift our focus to benchmarks and performance.

When we started out we knew very little about the EraVM. We knew it was different from the EVM, and had indirectly used `zksolc` to compile and deploy contracts to the network, but had not looked much into the underlyings of it.

The first thing we did to get into a working flow was to inspect the VM's bytecode. We compiled simple contracts into EraVM assembly and started getting familiar with it. The goal when starting out on an unfamiliar VM is to setup a simple `fetch->decode->execute` loop that looks something like this:
    
    fn run(
        vm: VM,
    ) {
        loop {
            let opcode = vm.get_opcode(&opcode_table)?;
    
            match opcode {
                    Opcode::Add => todo!(),
                    Opcode::Sub => todo!(),
                    Opcode::Jump => todo!(),
                    Opcode::Mul => todo!(),
                    Opcode::Div => todo!(),
                    ... => ...
            }
            vm.pc += 1;
        }
        ...
    }
    

and then progressively implement all the opcodes. When we started looking at the assembly generated on contracts we realized the EraVM was a lot more complex than the EVM in terms of opcodes; fortunately, Matter Labs has a [very good primer on them](https://github.com/matter-labs/zksync-era/blob/main/docs/specs/zk_evm/vm_specification/zkSync_era_virtual_machine_primer.md) and a [full formal specification](https://matter-labs.github.io/eravm-spec/spec.html).

After reading those and reading their own implementations, we stumbled into their own repo [defining all the VM opcodes](https://github.com/matter-labs/era-zkevm_opcode_defs), and from there we could setup a proper loop like the above.

With it, we started writing our own simple EraVM assembly programs testing all the different opcodes as we implemented them. Eventually, after getting the basic functionality in place, these simple assembly programs we wrote started becoming insufficient to test complex interactions like contracts calling other contracts, gas management, etc; we needed a proper test suite.

That proper test suite is the [era-compiler-tester](https://github.com/matter-labs/era-compiler-tester), a full test suite for the VM written by Matter Labs (technically this is also a test suite for the `zksolc` compiler itself, but we care about VM testing here). To get a fully working VM, we realized we needed to make these tests pass.

Before going into detail about them, let's do a quick overview of the VM we set to reimplement.

## EraVM Overview

ZKsync is a zk-Rollup meant to be EVM compatible. In practice, this can mean a number of different things. For ZKsync, it means that it's compatible at the programming language level; this is done through `zksolc`, an LLVM based compiler written by Matter Labs that takes any Solidity, Yul or Vyper contract and compiles it down to the EraVM bytecode.

This might seem like full compatibility, but it's not. The EraVM has a completely different architecture than the EVM, and some of these differences cannot be fully abstracted away.

As an example, the following Solidity contract:
    
    contract Test {
        function main(uint256 a, uint256 b) external pure returns(uint256 result) {
            result = a + b;
        }
    }
    

compiles to an EVM assembly that looks like this:
    
    PUSH1 0x80
    PUSH1 0x40
    MSTORE
    CALLVALUE
    DUP1
    ISZERO
    PUSH1 0xE
    JUMPI
    ...
    

and an EraVM assembly that looks like this:
    
    add	 128, r0, r3
    st.1	 64, r3
    and!	1, r2, r0
    jump.ne	@.BB0_1
    add	 r1, r0, r2
    shr.s	96, r2, r2
    and	 @CPI0_0[0], r2, r2
    sub.s!	4, r2, r0
    jump.lt	@.BB0_2
    ld	r1, r3
    ...
    

Clearly these are very different VMs. This requires getting used to these two different architectures when working at the VM level on ZKsync. A lot of operations that are opcodes on the `EVM` are not on the `EraVM`.

For instance, the EVM has a `returndatacopy` opcode, which copies the output data from a previous contract call into memory. On the `EraVM` there is no such thing; a call to `returndatacopy` on a Yul contract will compile to a block of code that looks like this:
    
    .BB0_19:
      ld.inc	r5, r7, r5
      st.1.inc	r6, r7, r6
      sub!	r6, r4, r0
      jump.ne	@.BB0_19
    

We omitted some context, but this is essentially just a loop that will continously load (`ld`) a word from the called contract's memory and then store it (`st`) on the caller contract's memory, then conditionally jump back (`jump.ne`) to the loop if the copying is not done yet (i.e. if the `sub!` instruction does not yield zero).

This is just one example: most complex EVM opcodes work in in a similar fashion on the EraVM.

## Era Compiler Test suite

There are millions of tests on the `era-compiler-tester` repo, but they all follow the same structure. Each test is a Solidity, Yul or Vyper contract that is compiled with `zksolc` and run with certain inputs, in turn expecting certain outputs. As an example, the [default.sol](https://github.com/matter-labs/era-compiler-tests/blob/fe7d0e86d06130ee266f82b04a549918da615521/solidity/simple/default.sol) test looks like this:
    
    //! { "cases": [ {
    //!     "name": "first",
    //!     "inputs": [
    //!         {
    //!             "method": "first",
    //!             "calldata": [
    //!             ]
    //!         }
    //!     ],
    //!     "expected": [
    //!         "42"
    //!     ]
    //! }, {
    //!     "name": "second",
    //!     "inputs": [
    //!         {
    //!             "method": "second",
    //!             "calldata": [
    //!             ]
    //!         }
    //!     ],
    //!     "expected": [
    //!         "99"
    //!     ]
    //! } ] }
    
    // SPDX-License-Identifier: MIT
    
    pragma solidity >=0.4.16;
    
    contract Test {
        function first() public pure returns(uint64) {
            uint64 result = 42;
            return result;
        }
    
        function second() public pure returns(uint256) {
            uint256 result = 99;
            return result;
        }
    }
    

The comment above it specifies what the test should run and what it expects. In this case, there are two tests, which should run the methods `first` and `second` and then get `42` and `99` as a result respectively. Most tests have a lot of comments specifying different runs, testing different functions with different inputs/outputs and so on.

## Deep dive into a ZKsync Era contract

Let's compile the `default.sol` program above and see what it's doing under the hood. Running
    
    zksolc default.sol --asm -o default --optimization 3 --overwrite
    

will place a `default.zasm` file under the `default` directory. This is the EraVM assembly for the contract:
    
    	.text
    	.file	"default.sol:Test"
    	.globl	__entry
    __entry:
    .func_begin0:
    	add	128, r0, r3
    	st.1	64, r3
    	and!	1, r2, r0
    	jump.ne	@.BB0_1
    	add	r1, r0, r2
    	and!	@CPI0_1[0], r2, r0
    	jump.eq	@.BB0_2
    	ld	r1, r1
    	shr.s	224, r1, r1
    	sub.s!	@CPI0_2[0], r1, r0
    	jump.eq	@.BB0_10
    	sub.s!	@CPI0_3[0], r1, r0
    	jump.ne	@.BB0_2
    	context.get_context_u128	r1
    	sub!	r1, r0, r0
    	jump.ne	@.BB0_2
    	add	42, r0, r1
    	st.1	128, r1
    	add	@CPI0_4[0], r0, r1
    	ret.ok.to_label	r1, @DEFAULT_FAR_RETURN
    .BB0_1:
    	context.get_context_u128	r1
    	sub!	r1, r0, r0
    	jump.ne	@.BB0_2
    	add	32, r0, r1
    	st.2	256, r1
    	st.2	288, r0
    	add	@CPI0_0[0], r0, r1
    	ret.ok.to_label	r1, @DEFAULT_FAR_RETURN
    .BB0_10:
    	context.get_context_u128	r1
    	sub!	r1, r0, r0
    	jump.ne	@.BB0_2
    	add	99, r0, r1
    	st.1	128, r1
    	add	@CPI0_4[0], r0, r1
    	ret.ok.to_label	r1, @DEFAULT_FAR_RETURN
    .BB0_2:
    	add	r0, r0, r1
    	ret.revert.to_label	r1, @DEFAULT_FAR_REVERT
    .func_end0:
    
    	.note.GNU-stack
    	.rodata
    CPI0_0:
    	.cell	53919893334301279589334030174039261352344891250716429051063678533632
    CPI0_1:
    	.cell	340282366604025813406317257057592410112
    CPI0_2:
    	.cell	1519042605
    CPI0_3:
    	.cell	1039457780
    CPI0_4:
    	.cell	2535301202817642044428229017600
    

A few things you need to know about the EraVM before diving in:

        * The native word is a `U256` (256 bit unsigned integer).
        * There are 16 registers, `r0` through `r15`.
          * `r0` is the zero register: writing to it does nothing, reading from it yields zero.
          * `r1` is used as a pointer to the calldata (i.e. function arguments) when calling other contracts, and to the returndata when returning from calls.
          * `r2` usually stores information about whether the current call is a constructor call, a regular function call, or a system call (a call to a system contract with special privileges).
        * Every contract call gets its own stack and heap memory.

### Step by Step

Let's do a step by step overview of this assembly.

When someone calls this contract, execution always begins from the `__entry` symbol. The first two instructions are doing some setup we don't care much for, storing the value `128` onto the `r3` register:
    
    add	128, r0, r3
    st.1 64, r3
    

In more detail, `add 128, r0, r3` adds `128` to the value in `r0` and stores it in `r3`. Because `r0` is the zero register, this is essentially storing `128` in `r3` (this the way `mov`s to registers are always done in the EraVM).  
`st.1` then stores the value in `r3` to memory address `64` (if you're wondering what the `1` is in `st.1`, it's the type of heap to use; the EraVM has both a regular and a special _auxiliary_ heap).

Then, there's a check on the `r2` register and a conditional jump:
    
    and! 1, r2, r0
    jump.ne	@.BB0_1
    

The `and!` instruction is doing a bitwise `and` between `1` and `r2`, storing it to `r0`, then setting the zero flag accordingly. This is storing to `r0` because we don't care about the result. We are just checking whether the `r2` register is 1 or not. If it is, then this is a constructor call, and we should jump to block `@.BB0_1`, which contains the constructor logic; if it's not we should continue.

If the call is not a constructor call, the code will then do
    
    add	r1, r0, r2
    and!	@CPI0_1[0], r2, r0
    jump.eq	@.BB0_2
    

This puts the `calldata` pointer that's in `r1` into `r2`, then does an `and` instruction and a conditional jump to make sure it's not pointing to an invalid address. If it is, then execution jumps to block `@.BB0_2`, which contains the revert logic:
    
    .BB0_2:
      add	r0, r0, r1
      ret.revert.to_label	r1, @DEFAULT_FAR_REVERT
    

If the address is valid, the code follows like this:
    
    ld	r1, r1
    shr.s	224, r1, r1
    

This is loading the first 32 bytes the calldata pointer points to through an `ld` instruction, storing it in `r1`, then shifting it `224` bits to the right to keep only its first 4 bytes (`256`\- `224` = `32` bits = 4 bytes).

These 4 bytes are the _function selector_ of this contract call. This `default.sol` contract has two functions
    
    function first() public pure returns(uint64)
    function second() public pure returns(uint256)
    

The selector for the first one is `0x3df4ddf4`, while for the second one it's `0x5a8ac02d` (you can check them yourself [here](https://www.evm-function-selector.click/)). If you convert these values to decimal, you'll see these are the values for the labels `CPI0_3` and `CPI0_2` respectively in the assembly. That's why the code does a `sub.s!` instruction, comparing the result of this selector in `r1` against `CPIO_2`
    
    sub.s!	@CPI0_2[0], r1, r0
    jump.eq	@.BB0_10
    

If the value matches, execution jumps to block `.BB0_10`, containing the logic for the `second` function that just returns `99`:
    
    .BB0_10:
      context.get_context_u128	r1
      sub!	r1, r0, r0
      jump.ne	@.BB0_2
      add	99, r0, r1
      st.1	128, r1
      add	@CPI0_4[0], r0, r1
      ret.ok.to_label	r1, @DEFAULT_FAR_RETURN
    

You can see the `add 99, r0, r1` followed by `st.1 128, r1` to store the return value into memory. The code before it is just checking whether the caller passed any `wei` using the `context.get_context_u128 r1` instruction, and reverting if so (this function is not payable).

If the selector did not match `CPI0_2` (the selector for the `second()` function), then the code checks against the `first()` selector (label `CPIO_3`):
    
    sub.s!	@CPI0_3[0], r1, r0
    jump.ne	@.BB0_2
    

In this case, because it's the last valid function selector for the contract, if the value does not match we just go to the revert block `BB0_2`. If it does match we continue with the logic for the `first()` function, doing the same but returning `42` instead of `99`:
    
    context.get_context_u128	r1
    sub!	r1, r0, r0
    jump.ne	@.BB0_2
    add	42, r0, r1
    st.1	128, r1
    add	@CPI0_4[0], r0, r1
    ret.ok.to_label	r1, @DEFAULT_FAR_RETURN
    

And that's it, that's the entire EraVM assembly code for this contract. To summarize, the code is organized as follows:

        * The `__entry` block is the entrypoint for any call to this contract.
        * Block `BB0_1` contains the contract's constructor logic (the default one in this case, since we didn't write one ourselves).
        * Block `BB0_10` contains the code for the `second()` function.
        * Block `BB0_2` just has the revert logic.
        * When someone calls this contract the code will do, in order, the following:
          * Check whether this is a constructor call and jump to `BB0_10` if so.
          * Read from the `calldata` pointer, revert by jumping to `BB0_2` if the address it points to is invalid.
          * Get the first 4 bytes of calldata to obtain the function selector.
          * Check the provided selector against the `second()` selector stored in `CPI0_2`. Jump to block `BB0_10` if it matches.
          * Check whether the selector matches `first()`. Revert if it does not, run the code for `first()` otherwise.

## Current status and next steps

We are working on the last stretch of fixes to make all tests pass. Once that's done, our focus will shift entirely to benchmarking the VM and start making optimizations. In anticipation for this, we started integrating with the [ZKsync Era benchmarks](https://github.com/matter-labs/zksync-era/tree/main/core/tests/vm-benchmark). This work requires [integrating the VM with the `bootloader`](https://github.com/lambdaclass/zksync-era/pull/225), the contract in ZKsync that executes blocks (essentially the network's main execution entrypoint).

This bootloader integration will also allow us to get our VM plugged into a ZKsync operator and start playing around with optimistic parallel execution ideas. Actually, getting parallel execution will probably involve modifying the bootloader or getting rid of it altogether when executing on the operator, but that's a topic for another post.
