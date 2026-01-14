+++
title = "Responsible disclosure: A potential sequencer-prover inconsistency in the Cairo VM"
date = 2025-02-07
slug = "responsible-disclosure-a-potential-sequencer-prover-inconsistency-in-the-cairo-vm"
description = "On January 26th Starkware informed us that they had found a critical issue in the Cairo VM related to a program that would successfully execute on the VM but would violate the AIR constraints. A fix was already implemented in a PR, merged, and a release was made and deployed."

[extra]
feature_image = "/images/2025/12/Delacroix_barque_of_dante_1822_louvre_189cmx246cm_950px.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["cairo", "starknet"]
+++

## Overview

On Sunday, January 26th, Starkware informed us that they had found a critical issue in the [Cairo VM](https://github.com/lambdaclass/cairo-vm) related to a program that would successfully execute on the VM but would violate the AIR constraints. The bug was found while investigating a separate issue reported by a third party and a fix was already implemented in a PR. The PR was merged, and a release was cut, which is already updated. You can read Starkware’s disclosure post [here](https://community.starknet.io/t/remediating-a-potential-sequencer-prover-inconsistency-in-the-cairo-vm/115313).

### Technical Implementation

The fix in pull request [#1925](https://github.com/lambdaclass/cairo-vm/pull/1925) adds two changes:

        * Additional verification while decoding instructions
        * Additional verification on `verify_secure_runner`.

#### Instruction Decoding**: Call Instruction**

The call instruction does roughly the following:

        1. Saves the current frame pointer to `[ap]`
        2. Saves the call return address to `[ap + 1]`
        3. Updates both `fp` and `ap` to `ap + 2`, skipping over the saved data.
        4. Updates the `pc` to the start of the target function

As some of the flags of the call instruction are fixed, we can verify that:

        * The `dst` register holds `ap+0`, where the current frame pointer will be stored.
    
    dst_register == AP
    dst_offset   == 0
    

        * The `op0` register holds `ap+1`, where the call return address will be stored.
    
    op0_register == AP
    op0_offset   == 1
    

        * Both `fp` and `ap` are updated to `ap+2`:
    
    ap_update == Add2
    fp_update == APPlus2
    

If these conditions are not met, the decoding fails.

#### Instruction Decoding**: Return Instruction**

The return instruction does roughly the following:

        1. Restores the previous frame pointer (at `[fp - 2]`)
        2. Jumps to the call return address (at `[fp - 1]`)

As some of the flags of the return instruction are fixed, we can verify that:

        * The program counter is updated with an absolute jump
    
    pc_update == Jump
    

        * The jump location is taken from `res`, which equals `fp-1`:
    
    res_logic   == Op1
    op1_offset  == -1
    op1_address == FP
    

        * The next frame pointer is taken from `dst`, which equals `fp-2`
    
    fp_update    == Dst
    dst_register == FP
    dst_offset   == -2
    

If these conditions are not met, the decoding also fails.

#### Conditional Jump

This PR also enforces that when `pc_update` is equal to `4` (conditional jump), then `res_logic` must equal `0` (which implies ignoring that field).

> This behavior is documented in the Cairo Whitepaper, page 33:
    
    if pc_update == 4:
        if res_logic == 0 && opcode == 0 && ap_update != 1:
            res = Unused
        else:
            Undefined Behavior
    

#### **Secure runner verification**

The `verify_secure_runner` function verifies that the completed run in a runner is safe to be relocated and used by other Cairo programs.

The PR verifies that the final frame pointer coincides with the caller's frame pointer, stored at `[initial_frame_pointer - 2]`.

        * When using `ExecutionMode::ProofModeCanonical`, the whole address must match.
        * When using `ExecutionMode::RunnerMode`, only the offset must match.

### Impact Analysis

As noted in Starkware’s [release](https://community.starknet.io/t/remediating-a-potential-sequencer-prover-inconsistency-in-the-cairo-vm/115313): 

> ”Since the missing check was in the sequencer and not the prover this has no implication whatsoever on the correctness or security of Starknet. In theory, it could have created a situation that a transaction that appears to have passed will later be reverted (reorg)”

the main risk was having transactions from `Cairo0` contracts execute on the sequencer and revert instead of being proved. Since the transaction would not pass the prover there is no risk of incorrect transaction being proved but the revert would impact user experience.

## Conclusion

As we’ve stated before, issues such as this one are always possible and likely in complex software and highlight the importance of having multiple teams paying attention to security, close collaboration between them, having simple codebases, and scrutinizing the interactions between components.

Many thanks to Starkware for the notice and quick fix!
