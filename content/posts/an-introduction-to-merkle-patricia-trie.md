+++
title = "An introduction to Merkle Patricia Trie"
date = 2025-06-09
slug = "an-introduction-to-merkle-patricia-trie"

[extra]
feature_image = "/images/2025/12/Pallas_Athena_by_Rembrandt_Museu_Calouste_Gulbenkian_1488.jpg"
authors = ["LambdaClass"]
+++

## Introduction

Ethereum relies on cryptographic data structures to efficiently store and verify its state. One of these structures is the Merkle Patricia Trie (MPT), which powers Ethereum’s state management. After exploring this tool in more depth, it becomes clear that the MPT is a complex structure—far more intricate than a simple Merkle tree. That’s why we felt it was important to create this post: to make MPTs more accessible and easier to understand. Here we'll explain what an MPT is, how Ethereum uses it and how its proofs work. In an upcoming post, we will explain how to arithmetize the MPT to be able to generate proofs for showing that we verified that elements are in the tree or that the tree has been updated successfully.

In what follows we only assume that you have a basic knowledge of [Merkle Trees](https://decentralizedthoughts.github.io/2020-12-22-what-is-a-merkle-tree/) and cryptographic hash functions.

## Quick Merkle Tree Recap

A Merkle Tree is a binary tree where:

        * _Leaves_ contain hashes of data.
        * _Non-leaf nodes_ contain hashes of the concatenation of their child nodes.
        * The _root hash_ acts as a cryptographic fingerprint of all the leaves data. In other words, it's a short, fixed-size summary (a hash) that uniquely identifies a large set of data — like a unique signature.

Merkle trees are used for **data integrity proofs** : you can prove efficiently that a piece of data belongs to the tree's leaves by providing a Merkle path (a sequence of hashes from the leaf to the root).

## What is a trie?

A Trie (short for retrieval tree, also known as a prefix tree) is a tree-like data structure used to efficiently store and retrieve key-value pairs, especially when the keys are strings or sequences.

Each level of the trie represents a character in the key, and the path from the root to a leaf corresponds to an entire key. Shared prefixes between keys are stored only once, making tries very space-efficient for datasets with common prefixes.

Let's see a toy example to make it easier to understand. Let's say we want to store these key-value pairs:

Key | Value  
---|---  
cat | curious  
cake | sweet  
cup | fragile  
cups | plural  
book | heavy  
  
Our toy trie would look something like this:

![image](https://hackmd.io/_uploads/HyXnHtvzgl.png)

To look up the value of the key "cake":

        1. Start at the root.
        2. Follow the nodes corresponding to the key's characters: `c -> a -> k -> e`.
        3. Retrieve value "sweet" at the last node `e`.

## What is a Merkle Patricia Trie?

Ethereum uses a specialized form of trie called the Modified Merkle Patricia Trie (MPT). The name combines three core ideas:

        * **Trie:** For organizing keys by shared prefixes.
        * **Merkle:** Every node is hashed, forming a Merkle structure that enables cryptographic verification of the entire dataset.
        * **Patricia:** Short for Practical Algorithm to Retrieve Information Coded in Alphanumeric — a variant of a trie that compresses paths where nodes have a single child (also called radix or compact trie).

## How are MPTs used in Ethereum?

Ethereum uses several MPTs, but we'll focus on just one of them, the **State Trie** , and use it as an example to explain how they work.

In the State Trie, the state of every account is stored as a key-value pair where:

        * The **key** is the Keccak-256 hash of the account address.
        * The **value** is the account, which is the [RLP](https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/) encoding of a four item array: `[nonce, balance, storageRoot, codeHash]`.

To reach consensus, when a new block appears with a transaction set, every Ethereum node would need to execute all those transactions and verify that the resulting state is the same for all the nodes. However, comparing every account would be computationally very expensive, so instead they use an MPT. The states of all the accounts of Ethereum are stored in a single Merkle trie called **State Trie** that is constantly updated after each transaction execution. To reach consensus, the nodes just compare the **StateRoot** (the root of the State Trie). If two nodes have the same StateRoot, their states match.

## Immutability: The big MPT's advantage

Ethereum needs to be able to revert easily to previous states: when nodes disagree on the next block, a blockchain fork is necessary. This is possible because tries keep the old state around, instead of deleting or modifying it directly. The trie is persistent and versionable, rather than a mutable in-place structure.

When the state changes (e.g., an account balance updates), the trie creates new nodes for the changed paths, while the rest of the trie (the unchanged parts) are reused. Therefore, previous versions of the trie are still accessible via their root. Every block stores a state root in its header and this root uniquely identifies the entire Ethereum state at that point in time. So, if Ethereum needs to rollback, it just uses the state root of a previous block. Since the old nodes were never deleted, the trie can rebuild the old state efficiently. This means Ethereum can restore the old state just by switching back to an earlier root hash.

## MPT Structure

Let's explain how the State Trie is built. As we said above the keys of this trie consist of the hashes of the addresses, represented as a hexadecimal string. As we showed in the toy example, each node of the trie will store a character of the hex string, that is, a single [nibble](https://en.wikipedia.org/wiki/Nibble) (four bits of data).

There are three types of nodes in an MPT:

        1. **Branch Node**
           * It stores a 17-item array.
           * The first 16 items represent one of each hexadecimal digit the key prefix can be. If the key prefix is the digit $i$, then at index $i$ you'll find the pointer to the next node that continues the key's path.
           * The last item can allocate a value in the case a key ends there.
           * Example:  
`[0x, 0x, child_hash, 0x, 0x, other_child_hash, 0x, 0x, 0x, 0x, 0x, 0x, 0x, 0x, 0x, 0x, value]`  
Here, `"0x"` represents the unused slots, i.e. digits that don't have children.
        2. **Extension Node**
           * It's the result of an optimization to compresses shared key prefixes.
           * It stores a two item array that contains the shared key prefix and a pointer to the next node.
           * Example: `[shared_prefix, child_hash]`
        3. **Leaf Node**
           * It stores a two item array with the remaining key fragment and its associated value, ending the path.
           * Example: `[key_remaining, value]`

The three types of nodes store a single array encoded in [RLP](https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/). The pointer to a certain node is always the hash of this RLP string data that stores. The root can be of any type, but usually, since we have a lot of data, the root is a branch node.

### Node and parity flags

When traversing a key path nibble by nibble (or character by character), we may end up with a leaf or extension node that has an odd number of nibbles to store. But since all data is stored in bytes, this creates a problem. For instance, if we wanted to store the nibble `1`, we would have to save it as `01`, but we wouldn’t be able to tell whether it came from the two nibbles `01`, or from a single nibble `1`. To indicate whether we are storing an even or odd number of nibbles — and what type of node we are dealing with (leaf or extension) — the partial path is prefixed with the following flags.

flag | node type | path length parity  
---|---|---  
00 | Extension | Even  
1 | Extension | Odd  
20 | Leaf | Even  
3 | Leaf | Odd  
  
## Example: Building an MPT step by step

The best way to understand what is an MPT is to see a full example. Let’s simulate a real State Trie. Let's say we have data for five accounts that translate into the following key-value pairs:

- | Keys | Values  
---|---|---  
1 | 0x616b6c64 | 0x01  
2 | 0x616b6c65 | 0x02  
3 | 0x616b6c78 | 0x03  
4 | 0x616b6d31 | 0x04  
5 | 0x31323334 | 0x05  
  
As we mentioned earlier, the keys should be the hashes of the account addresses. Since Ethereum uses Keccak-256, the keys should be 32 bytes long (or 64 hexadecimal characters). However, for this example, we'll use much shorter keys so that the resulting trie isn't too large and is easier to understand. Ethereum also uses optimizations, such as inlining small nodes, which we’ll skip in this example for clarity.

Now we are ready to build the MPT:

        1. Start with an empty MPT and add the first key-value pair: `(0x616b6c64, 0x01)`. Since it is just one key, it results in a trie of only one leaf node. To create that node proceed in the following way:

           * **Write a two-item array:** The first element should be the whole key and second one the value. Add the prefix flag `20` to the first element indicating that the node is a leaf and that the key has an even amount of nibbles. Then, the array should look like this: `["0x20616b6c64","0x01"]`.
           * **Encode in RLP the array:** You can use an [RLP converter](https://toolkit.abdk.consulting/ethereum#rlp) or this python script:
    
    import rlp
    
    key = bytes.fromhex("20616b6c64")
    value = bytes.fromhex("01")
    encoded = rlp.encode([key, value])
    print(encoded.hex())
    

This should output this hex: `c78520616b6c6401`.

           * **Hash the RLP encoding** using Keccak-256 to get the pointer of this node. You can use an [online hasher](https://emn178.github.io/online-tools/keccak_256.html) or this script:
    
    from eth_utils import keccak
    
    rlp_bytes = bytes.fromhex("c78520616b6c6401")
    hash_pointer = keccak(rlp_bytes)
    print(hash_pointer.hex())
    

This should output:
    
    4e2d0fbe6726eac15c5ecf49a4e1f947aa50e0531f4f3e98b8e1577ba52e1783
    

The resulting MPT should look like this:  
![image](https://hackmd.io/_uploads/BJ7XSE1mex.png)

        2. Add the second key-value pair: `(0x616b6c65, 0x02)`. Since this key shares the first 7 digits with the previous one, we proceed in the following way:

           * **Build one leaf for each key:** In each leaf, the array's first element should be the remaining path, but since the two keys share every digit except the last one, the remaining path is empty. So, we should just write there the flag `20` indicating that we are in a leaf node and that the path has an even amount of digits (zero digits). After that, encode the arrays in RLP and hash the RLP encodings, as we did in the step 1.
           * **Build a branch node:** Create a 17-item array. Write the hash of the first key's leaf node at index $4$ and the hash of the second key's leaf node at index $5$. Encode the array in RLP and hash the encoding.
           * **Build the extension and root node:** Create a two item array that contains the shared prefix as first element and the hash of the previous built branch node as second element. Since the shared prefix has an odd number of digits, add the flag `1` to it. Encode the array in RLP and hash the encoding.  
![image](https://hackmd.io/_uploads/BJaRZEJQll.png)
        3. Add the key-value pair `(0x616b6c78, 0x03)`:

           * **Add a leaf node:** Notice that in this case, since the new key shares with the previous ones all the digits except the last two, the array's first item will have just one digit as remaining path and the flag `3` indicating that it is a leaf node with an odd amount of path digits.
           * **Add a branch node:** Its array should contain at index $6$ the hash pointer of the branch node built in step 2, and at index $7$ the hash pointer of the new leaf node we recently added.
           * **Add an extension node:** The root will be another extension node. Its array should contain the shared prefix as first element and the hash of the recently added branch node as second element. Since the share prefix has an even number of digits, add the flag `00` to it.

The current trie should look lik this:  
![image](https://hackmd.io/_uploads/HJrfJHJXee.png)

        4. Add the last two key-value pairs continuing in this way, following the same steps as we did for the previous keys. When you're done, you should have the following MPT:  
![image](https://hackmd.io/_uploads/Skc3rByXee.png)

## Trie Proof

Let’s now understand what a proof looks like in an MPT. Continuing with the previous example, let's say we want to prove that the key-value pair `(0x616b6d31, 0x04)` belongs to our State Trie. How do we build the proof?

The proof will consist of the **StateRoot** `0x13ea...bed7` (the hash of the root node) along with a path that starts at the root and traverses the trie downward, following every digit of the target key until it reaches its leaf. Let’s go step by step to see how we build this path:

        1. The first element of the path is the RLP of the root node: `0xf851...8080`.  
If we decode this RLP, we find that the root is a branch node. The array it represents has all empty slots except at indices 3 and 6 (because all the keys start with the digit `3` or `6`). This means that the root node branches into two child nodes. Since the first digit of the key we’re looking for is `6`, we need to look at the hash stored in the array at index 6 and move to that node.

        2. We move to the next node and store its RLP content as the second element of the path: `0xe583...67e9`.  
This node is an extension node because all keys starting with 6 share the same next four digits: `16b6`. To determine where to go next, we decode the RLP and get a two-item array. The second item gives us the hash of the next node we need to access.

        3. Again, we move to the next node and store its RLP content as the third element of the path: `0xf851...8080`.  
This node is a branch node. Since our key continues with the digit `d`, we need to look at the hash stored in this node's array at index $d$ and move to the node that this hash points to.

        4. Finally, we reach the leaf node: `0xc482203104`. We store the RLP content of this final node, and with that, the proof is complete.

Then the proof for the key-value `(0x616b6d31, 0x04)` should look like this:
    
    state_root = 0x13ea549e268b5aa80e9752c6be0770cffba34d2b1aa1f858cb90f3f13ac3bed7
    
    proof_path = 
        [
        0xf851808080a0a26b2ac124718443aeed68fa0309225d0c8dd9dbee45685909e92fb594e1a4638080a02ccd118c9470c051689543b233ab109ad74d2fb4f57eb429c4d43294d6ae686780808080808080808080,
        0xe5831616b6a0917fa5cab26d915e2a89a263a578fa5f9ecf02cc0b1d3eeb433e7f32499267e9,
        0xf851808080808080808080808080a0cc97f12ea3217345e666974cd81b117ca02404f19c15d31158ac1d1e55398706a0822a55ca308aa885ad385d5e61aabaca54c2e4361eb03b6f851668c0f095ab77808080,
        0xc482203104
        ]
    

## Verify

If a verifier receives the StateRoot and the proof path for a certain key, how does he verify that the proof is valid?

A key distinction from standard Merkle Trees is the verification direction. While a typical Merkle proof is verified from the bottom up (from the leaf to the root), a Merkle Patricia Tries proof is verified from the top down. The process starts at the `StateRoot` and traverses the trie downwards, node by node, using the provided path to eventually reach the target leaf.

Let's say the verifier receives the proof of above for the key-value `(0x616b6d31, 0x04)`. Then, he has to follow these steps:

        1. [Hash](https://emn178.github.io/online-tools/keccak_256.html) the first element of the path and check that it matches the given **StateRoot**. Indeed:
    
    keccak(bytes.fromhex(
        "f851808080a0a26b2ac124718443aeed68fa0309225d0c8dd9dbee45685909e92fb594e1a4638080a02ccd118c9470c051689543b233ab109ad74d2fb4f57eb429c4d43294d6ae686780808080808080808080"
    )).hex() ==
        "13ea549e268b5aa80e9752c6be0770cffba34d2b1aa1f858cb90f3f13ac3bed7"
    

        2. [Decode](https://toolkit.abdk.consulting/ethereum#rlp) the **first RLP element** of the path and verify that in the index $6$ has the hash of the second path element. Indeed:
    
    rlp.decode(bytes.fromhex(
        "f851808080a0a26b2ac124718443aeed68fa0309225d0c8dd9dbee45685909e92fb594e1a4638080a02ccd118c9470c051689543b233ab109ad74d2fb4f57eb429c4d43294d6ae686780808080808080808080"
    ))[6].hex() ==
        "2ccd118c9470c051689543b233ab109ad74d2fb4f57eb429c4d43294d6ae6867"
    

        3. Decode the **path's second RLP element**. You'll find a two-item array whose first element is `0x1616b6`. Since its first digit is `1` we know that we are on an extension node. Check that the rest of the digits correspond to the key we are looking for. Verify the array's second element is the hash of the path's next element.

        4. Decode the **third path element**. You'll find a branch node. Verify that at index $d$ it stores the hash of the path's element.

        5. Decode the **path's last element**. You'll find a two item array whose first element is `0x2031`. Since its firs two digits are `20`, we know that we reach a leaf node. Verify that the first item contains the remaining key's digits `31` and the second item contains the key's value `0x04`.

## Summary

The Merkle Patricia Trie is the backbone of Ethereum’s state management. It combines the key-navigation efficiency of tries, and the cryptographic guarantees of Merkle trees. This structure allows Ethereum to store, verify, and revert state efficiently and securely. With the MPT, Ethereum nodes can independently execute transactions and verify consensus simply by comparing state roots, enabling a scalable and trustless blockchain system. In an upcoming post we will develop how to arithmetize the MPT update and show that we verified inclusion proofs.
