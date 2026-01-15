+++
title = "Diving deep into Binius M3 arithmetization using Merkle tree inclusion as an example"
date = 2025-06-23
slug = "diving-deep-into-binius-m3-arithmetization-using-merkle-tree"

[extra]
math = true
feature_image = "/images/2025/12/Joshua_Commanding_the_Sun_to_Stand_Still_upon_Gibeon_-1816-_John_Martin_-_NGA_2004.64.1.jpg"
authors = ["LambdaClass"]
+++

## Introduction

At the heart of any Zero-Knowledge Proof (ZKP) system lies the concept of arithmetization, the process of transforming a computational problem into a mathematical problem that can be expressed and verified within a specific algebraic structure, such as polynomials or arithmetic circuits. Within the Binius framework, this arithmetization is managed through the **Multi-Multiset Matching (M3)** system, which introduces significant changes and improvements compared to more commonly used arithmetizations.

While previous posts focused on the mathematical foundations used by Binius—such as [binary fields](/the-fields-powering-binius/) and [additive FFT](/additive-fft-background/)—this post aims to explore how Binius M3 system is implemented. To do so, we take a deep dive into a specific gadget: the [Merkle tree](https://github.com/IrreducibleOSS/binius/tree/main/crates/m3/src/gadgets/merkle_tree). By walking through this example in detail, we aim to understand how constraint systems, tables, and channels are represented and handled in code.

To gain a more general intuition about why the tables and arithmetization techniques we explain in detail here actually work, we strongly recommend reading [Binius M3 documentation](https://www.binius.xyz/basics/arithmetization/m3). It’s very clear and presents toy examples that help illustrate the core ideas.

## M3 General Idea

Unlike traditional arithmetizations that often rely on a sequential main execution trace, M3 distinguishes itself by not requiring a main trace or for its tables to be sequential. In M3, tables are merely declarative instances, specifically designed for the purpose of the proof. The prover fills these tables with data relevant to the computation, and these tables serve as a source for interacting with a key component: channels.

Within M3, tables and channels are the fundamental pillars for building and verifying complex computations. **Tables** are the primary means of representing and structuring computation data, functioning as collections of columns where each row represents a step or an instance of an operation. For example, in the context of a Merkle Tree, some tables will have parent and children nodes data.

Complementing tables, **channels** act as communication conduits within the M3 constraint system. They facilitate the flow of data between different tables or between tables and the external world (such as public inputs and outputs). Tables **push** into or **pull** from channels data. This mechanism is crucial for connecting various parts of a complex computation, ensuring that data dependencies are correctly maintained and verifiable. To verify the validity of a proof, the verifier simply needs to check that all channels are **balanced** —meaning that the data pushed into a channel matches the data pulled from it.

While M3 also relies on polynomially-constrained tables, as previous schemes do, it departs from traditional approaches by using these tables solely to support channel balancing, rather than as a vehicle for constructing a global execution trace.

In this post, we'll explore specific examples of tables and channels within the Binius Merkle Tree constraint system, illustrating how they are used to build a verifiable proof of Merkle Tree inclusion. To see all of that theory in action, the Merkle Tree example wraps the setup in a single helper: `MerkleTreeCS`. A call to `MerkleTreeCS::new` sets up five tables, opens three channels, and returns a constraint system that’s ready to be filled with path data. With the plumbing taken care of, we can now look at what each table and channel does.

## MerkleTreeCS

The [MerkleTreeCS](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L45) (Merkle Tree Constraint System) consists of 5 tables and 3 channels that work together to ensure the correctness of Merkle paths verification.

### Tables

        * `merkle_path_table_left`: A table of type `NodesTable` that handles Merkle paths where only the left child must be pulled from a channel. We'll see in detail what this means later on.
        * `merkle_path_table_right`: A table of type NodesTable that handles cases where only the right child is pulled.
        * `merkle_path_table_both`: A table of type `NodesTable` that handles cases where both left and right children are pulled.
        * `root_table`: A table of type `RootTable` that reconciles the final values of Merkle paths with the expected roots.
        * `incr_table`: A table of type `IncrLookup`. A lookup table for increment operations to verify the depth relationships between parent and children nodes.

### Channels:

        * `nodes_channel` \- Manages intermediate nodes in Merkle paths (format: `[Root ID, Digest, Depth, Index]`)
        * `roots_channel` \- Handles root verification (format: `[Root ID, Digest]`)
        * `lookup_channel` \- Coordinates increment operations to verify that child depth is the parent depth plus one.

### Initialization

The `MerkleTreeCS::new()` method constructs the entire constraint system. The main goal of this method is to add the tables and channels to `cs` (the constraint system) and create the `MerkleTreeCS`.
    
    pub fn new(cs: &mut ConstraintSystem) -> Self {
        let nodes_channel = cs.add_channel("merkle_tree_nodes");
        let roots_channel = cs.add_channel("merkle_tree_roots");
        let lookup_channel = cs.add_channel("incr_lookup");
        let permutation_channel = cs.add_channel("permutation");  // ← NEW CHANNEL!
    
        // Create the three Merkle path tables
        let merkle_path_table_left =
            NodesTable::new(cs, MerklePathPullChild::Left, nodes_channel, lookup_channel);
        let merkle_path_table_right =
            NodesTable::new(cs, MerklePathPullChild::Right, nodes_channel, lookup_channel);
        let merkle_path_table_both =
            NodesTable::new(cs, MerklePathPullChild::Both, nodes_channel, lookup_channel);
    
        let root_table = RootTable::new(cs, nodes_channel, roots_channel);
    
        // Create the increment lookup table with the new permutation channel
        let mut table = cs.add_table("incr_lookup_table");
        let incr_table = IncrLookup::new(&mut table, lookup_channel, permutation_channel, 20);
        
        Self { /* ... */ }
    }
    

As can be seen, there is an extra channel not mentioned before:

The `permutation_channel` is a new channel introduced specifically for the `IncrLookup` table. This channel serves a crucial purpose in the lookup table verification process. It ensures that the two columns in IncrLookup are permutations of each other. These columns are called `entries_ordered` and `entries_sorted`, and we will examine them in detail later.

## An Example Step by Step

We believe that the best way to understand how the constraint system is built and how the tables are created is by looking at an example. For this, we’ll use the example provided by Binius in [merkle_tree.rs](https://github.com/IrreducibleOSS/binius/blob/main/examples/merkle_tree.rs), where we’ll be able to construct a tree, some paths, the constraint system, and the proof that validates those paths.

The file begins with some arguments that we’re going to adjust. For simplicity, we want to create a tree with 8 leaves and prove that two of them are part of the tree. In other words, we’ll take `default_value_t = 3` for the `log_leaves` (since we want an 8-leaves tree), `default_value_t = 1` for `log_paths` (since we want two prove two paths), and `default_value_t = 1` for `log_inv_rate`
    
    struct Args {
        /// The number of leaves in the merkle tree.
        /// By default 8 leaves.
        #[arg(long, default_value_t = 3, value_parser = value_parser!(u32).range(1..))]
        log_leaves: u32,
    
        /// The number of Merkle paths to verify.
        /// By default 2 paths.
        #[arg(short,long, default_value_t = 1, value_parser = value_parser!(u32).range(1..))]
        log_paths: u32,
        
        /// The negative binary logarithm of the Reed–Solomon code rate.
        #[arg(long, default_value_t = 1, value_parser = value_parser!(u32).range(1..))]
        log_inv_rate: u32,
    }
    

### Building the Tree and paths

Now that we have the arguments, if you follow the function [main()](https://github.com/IrreducibleOSS/binius/blob/main/examples/merkle_tree.rs#L39) you'll see that the tree and the Merkle paths are built there. Let's add some prints in this part of the code to see their values.
    
    /* ... */
    
    let mut rng = StdRng::seed_from_u64(0);
    // Create a Merkle Tree with 8 leaves
    let leaves = (0..1 << args.log_leaves)
        .map(|_| rng.r#gen::<[u8; 32]>())
        .collect::<Vec<_>>();
    
    let tree = MerkleTree::new(&leaves);
    
    let roots: [u8; 32] = tree.root();
    
    println!("--------- Merkle tree data -------");
    println!("Leaves: {:?}", leaves);
    println!("Root: {:?}", roots);
    
    let paths = (0..1 << args.log_paths)
        .map(|_| {
            let index = rng.gen_range(0..1 << args.log_leaves);
            println!("------- Path data -------");
            println!("Proving leaf index: {:?}", index);
            println!("Proving leaf: {:?}", leaves[index]);
            println!("Merkle tree path: {:?}", tree.merkle_path(index));
    
            MerklePath {
                root_id: 0,
                index,
                leaf: leaves[index],
                nodes: tree.merkle_path(index),
            }
        })
        .collect::<Vec<_>>();
    
    /* ... */
    

This should print first the eight leaves and the root (each of them is a 32-byte array):
    
    --------- Merkle tree data -------
    Leaves: [
        [127, 178, 123, 148, 22, 2, 208, 29, 17, 84, 34, 17, 19, 79, 199, 26, 172, 174, 84, 227, 126, 125, 0, 123, 187, 123, 85, 239, 240, 98, 162, 132], 
        [154, 99, 40, 60, 186, 240, 253, 188, 235, 31, 100, 121, 177, 151, 243, 168, 141, 208, 216, 9, 47, 231, 42, 124, 86, 40, 21, 56, 115, 139, 7, 226], 
        [114, 238, 165, 17, 148, 16, 151, 58, 227, 40, 173, 146, 145, 98, 104, 18, 142, 219, 71, 16, 110, 26, 214, 168, 195, 213, 69, 132, 155, 138, 184, 27], 
        [16, 24, 93, 38, 2, 59, 54, 16, 206, 183, 217, 245, 125, 73, 210, 179, 135, 99, 161, 43, 43, 189, 250, 147, 39, 90, 255, 24, 42, 251, 149, 220],
        [118, 35, 234, 226, 120, 82, 64, 185, 61, 18, 177, 106, 102, 216, 22, 16, 124, 220, 140, 137, 199, 16, 143, 255, 32, 149, 225, 141, 223, 239, 137, 134], 
        [177, 24, 234, 85, 97, 98, 77, 166, 204, 83, 123, 174, 213, 110, 96, 47, 147, 140, 128, 78, 39, 248, 49, 150, 97, 12, 136, 40, 199, 35, 247, 152], 
        [80, 79, 178, 164, 68, 97, 204, 11, 235, 179, 37, 40, 14, 217, 19, 10, 89, 187, 219, 49, 28, 1, 253, 115, 73, 9, 161, 31, 158, 72, 102, 40], 
        [180, 59, 54, 61, 129, 174, 139, 104, 153, 70, 236, 229, 198, 130, 205, 89, 138, 101, 234, 191, 246, 58, 53, 114, 223, 228, 95, 181, 173, 229, 139, 220]
    ]
    Root: [193, 178, 67, 64, 61, 105, 200, 119, 129, 200, 250, 91, 108, 49, 178, 161, 234, 142, 150, 145, 206, 128, 43, 153, 216, 191, 196, 183, 198, 179, 118, 122]
    

Then the first Merkle path:
    
    ------- Path data -------
    Proving leaf index: 3
    Proving leaf: [16, 24, 93, 38, 2, 59, 54, 16, 206, 183, 217, 245, 125, 73, 210, 179, 135, 99, 161, 43, 43, 189, 250, 147, 39, 90, 255, 24, 42, 251, 149, 220]
    Merkle tree path: [
        [114, 238, 165, 17, 148, 16, 151, 58, 227, 40, 173, 146, 145, 98, 104, 18, 142, 219, 71, 16, 110, 26, 214, 168, 195, 213, 69, 132, 155, 138, 184, 27], 
        [246, 247, 101, 36, 57, 192, 24, 48, 162, 208, 160, 30, 187, 154, 180, 176, 208, 104, 135, 216, 175, 8, 0, 249, 96, 50, 194, 72, 102, 219, 184, 27], 
        [70, 219, 30, 17, 251, 21, 8, 37, 23, 248, 120, 106, 49, 210, 42, 247, 15, 227, 231, 151, 101, 7, 187, 203, 29, 109, 186, 223, 43, 126, 183, 173]
    ]
    

And finally, the second Merkle path:
    
    ------- Path data -------
    Proving leaf index: 4
    Proving leaf: [118, 35, 234, 226, 120, 82, 64, 185, 61, 18, 177, 106, 102, 216, 22, 16, 124, 220, 140, 137, 199, 16, 143, 255, 32, 149, 225, 141, 223, 239, 137, 134]
    Merkle tree path: [
        [177, 24, 234, 85, 97, 98, 77, 166, 204, 83, 123, 174, 213, 110, 96, 47, 147, 140, 128, 78, 39, 248, 49, 150, 97, 12, 136, 40, 199, 35, 247, 152],
        [44, 37, 79, 124, 156, 84, 213, 102, 239, 101, 1, 89, 211, 73, 117, 58, 143, 41, 102, 47, 67, 32, 248, 100, 29, 138, 44, 204, 232, 177, 216, 54], 
        [124, 166, 97, 100, 173, 242, 98, 95, 141, 158, 147, 144, 202, 239, 150, 192, 0, 99, 9, 138, 61, 19, 65, 163, 160, 4, 227, 66, 233, 115, 199, 3]
    ]
    

So, our Merkle tree should look like the one below. To make the graph more readable, we only wrote the first byte of each node, even though we should have written all 32 bytes. The first path is shown in green, and the second one in blue. You may be wondering how we know the content of the middle nodes "181" and "67", since they are neither the leaves, the root, nor part of the Merkle paths. We got that information from prints we'll make later.

![image](/images/external/BJe-hoFQlx.png)

In the remainder of this post, we'll explain the three types of tables used in a `MerkleTreeCS`: **NodesTable** , **RootTable** and **IncrLookup**.

What are they for? How are they populated? How do they interact with the different channels? We'll answer these questions using the tree we just built as an illustration.

## NodesTable

### Purpose

This table type is designed to handle the relationships between parent and child nodes. Each row in the table corresponds to a `MerklePathEvent`, which captures the interaction between three related nodes: two children (left and right) and their parent.

When proving Merkle tree paths, the table is populated by traversing each path and creating one row for every parent-children trio encountered. This systematic approach ensures that all necessary node relationships are properly encoded and can be verified through the constraint system.

### Content and Columns

The [NodesTable](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L218) contains a set of columns that can be categorized into three main groups:

        1. **MerklePathEvent Data**  
These columns store the fundamental information about each node relationship:

           * `root_id`: Identifies which Merkle tree the three nodes belong to.
           * `left_columns`, `right_columns`: Store the digest values of the left and right child nodes.
           * `parent_depth`, `child_depth`: indicate the tree levels where the parent and children nodes are. The levels (or depths) start at 0 in the top (the root) and continues until $\log_2 (\text{leaves}.\text{len()})$, ending at the leaves.
           * `parent_index`, `left_index`, `right_index_packed`: Store the positional indices of nodes.
           * `_pull_child`: Specifies which child node needs to be pulled from the channel.
        2. **Groestl-256 Hash Computation**  
These columns handle the cryptographic hash operations:

           * `state_out_shifted`: Contains the concatenated bytes of left and right children organized for the Groestl-256 permutation.
           * `permutation_output_columns`: Store the bytes after the Groestl-256 output transformation.
           * `permutation`: The Groestl-256 permutation gadget.

> Note: This serves as a clear example of the power of gadgets. In a sense, the gadget responsible for verifying a Merkle path delegates the task of checking the validity of the hash function to another gadget (not detailed in this post, but it operates in an analogous way). This modular approach allows us to build proofs for more complex programs in a clean and scalable manner.

        3. **Depth Constraint**

`increment`: A gadget used to ensure the child node depth is exactly one more than the parent node depth.

### Initialization

The `NodesTable` is created through its [new()](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L249) method. This initialization process involves:

        * Adding the table to the **constraint system** using `cs.add_table()`.

        * Adding **committed columns** to the table using `table.add_committed()` or `table.add_committed_multiple()`.

        * Adding **virtual columns** to the table using `table.add_packed()`, `table.add_shifted()` and `table.add_computed()`. In the [Binius documentation](https://www.binius.xyz/building/pattern/declaring) you can see an explanation of the difference between committed and virtual columns.

> Note: This is particularly relevant in M3, as it represents one of the key differences compared to other proving systems. Virtual columns play a fundamental role by allowing the prover to commit only to a reduced number of tables (committed columns), while avoiding the need to commit to the virtual ones. The reason this is possible is that all the information required to reconstruct the virtual columns from the committed ones is fully encoded in the constraint system.

        * Establishing a **zero constraint** to ensure that the concatenation of left and right children nodes equals the input of the parent hash. This is implemented using `table.assert_zero()`.
    
    for i in 0..8 {
        table.assert_zero(
            format!("state_in_assert[{i}]"),
            state_in_packed[i]
                - upcast_col(left_packed[i])
                - upcast_col(right_packed[i]) * B64::from(1 << 32),
        );
    }
    

        * Setting up **flushing rules** that define how the table interacts with the [NodesChannel](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L409) using `nodes_channel.push()` and `nodes_channel.pull()`.

### Channel interaction

Let's explain a bit more the last point mentioned in the table initialization. The `NodesTable` interacts with the `NodesChannel` through the following push-pull rule: _Push Parent, Pull Child_.

        * **Push:** Parent node information (root ID, content, depth, and index) should be pushed to the channel.
        * **Pull:** Depending on the `pull_child` input, pull either the left child, right child, or both children from the channel. For each path, only one child should be pulled, left or right depending the path route. But if there is a parent-children trio Merkle event that is used in different paths once pulling left and once pulling right, then both children are pulled.

### Table population

The struct `NodesTable` implements the `TableFiller` trait, with the core population logic in the [fill()](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L508) function. For each `MerklePathEvent`, the function:

        * Extracts the node relationship data (parent, left child, right child)
        * Computes derived values like child indices and depth increments.
        * Fills the permutation state with the concatenated child node data.
        * Populates all table columns with the appropriate values.

This filling process transforms the trace data into the constraint system representation needed for proof generation and verification.

### Our Example

To understand what a `MerklePathEvent` is and how these tables are populated let's look at our example.

In the `main()` function of `merkle_tree.rs` example, once we have the tree and the paths, the trace is generated and after that the tables are filled using the function [fill_tables()](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L100). Here we can add more prints to see what all this data looks like.
    
    pub fn fill_tables(
        &self,
        trace: &MerkleTreeTrace,
        cs: &ConstraintSystem,
        witness: &mut WitnessIndex,
    ) -> anyhow::Result<()> {
        // Filter the MerklePathEvents into three iterators based on the pull child type.
        let left_events = trace
            .nodes
            .iter()
            .copied()
            .filter(|event| event.flush_left && !event.flush_right)
            .collect::<Vec<_>>();
        let right_events = trace
            .nodes
            .iter()
            .copied()
            .filter(|event| !event.flush_left && event.flush_right)
            .collect::<Vec<_>>();
        let both_events = trace
            .nodes
            .iter()
            .copied()
            .filter(|event| event.flush_left && event.flush_right)
            .collect::<Vec<_>>();
    
        println!("------- Merkle Path Events -------");
        println!("Left events: {:?}", &left_events);
        println!("Right events: {:?}", &right_events);
        println!("Both events: {:?}", &both_events);
    
    
        // Fill the nodes tables based on the filtered events.
        witness.fill_table_parallel(&self.merkle_path_table_left, &left_events)?;
        witness.fill_table_parallel(&self.merkle_path_table_right, &right_events)?;
        witness.fill_table_parallel(&self.merkle_path_table_both, &both_events)?;
    
        /*...*/
    }
    

This should print, first the left events:
    
    Left events: [
        MerklePathEvent { 
            root_id: 0, 
            left: [67, 45, 38, 237, 191, 26, 225, 172, 10, 94, 207, 176, 214, 146, 204, 230, 180, 241, 18, 217, 51, 18, 215, 92, 201, 50, 136, 22, 3, 172, 197, 55], 
            right: [44, 37, 79, 124, 156, 84, 213, 102, 239, 101, 1, 89, 211, 73, 117, 58, 143, 41, 102, 47, 67, 32, 248, 100, 29, 138, 44, 204, 232, 177, 216, 54], 
            parent: [70, 219, 30, 17, 251, 21, 8, 37, 23, 248, 120, 106, 49, 210, 42, 247, 15, 227, 231, 151, 101, 7, 187, 203, 29, 109, 186, 223, 43, 126, 183, 173], 
            parent_depth: 1, 
            parent_index: 1, 
            flush_left: true, 
            flush_right: false 
        }, 
        MerklePathEvent { 
            root_id: 0, 
            left: [118, 35, 234, 226, 120, 82, 64, 185, 61, 18, 177, 106, 102, 216, 22, 16, 124, 220, 140, 137, 199, 16, 143, 255, 32, 149, 225, 141, 223, 239, 137, 134], 
            right: [177, 24, 234, 85, 97, 98, 77, 166, 204, 83, 123, 174, 213, 110, 96, 47, 147, 140, 128, 78, 39, 248, 49, 150, 97, 12, 136, 40, 199, 35, 247, 152], 
            parent: [67, 45, 38, 237, 191, 26, 225, 172, 10, 94, 207, 176, 214, 146, 204, 230, 180, 241, 18, 217, 51, 18, 215, 92, 201, 50, 136, 22, 3, 172, 197, 55], 
            parent_depth: 2, 
            parent_index: 2, 
            flush_left: true, 
            flush_right: false 
        }
    ]
    

This event is a left one because the node that has to be pulled out from the channel is the left child "67":  
![image](/images/external/r19SajY7ee.png)  
The same with the second event. Here, the node that has to be pulled is the left child "118":  
![image](/images/external/HJF1CjYXee.png)

On the other hand, you should also see the prints of the right events:
    
    Right events: [
        MerklePathEvent { 
            root_id: 0, 
            left: [114, 238, 165, 17, 148, 16, 151, 58, 227, 40, 173, 146, 145, 98, 104, 18, 142, 219, 71, 16, 110, 26, 214, 168, 195, 213, 69, 132, 155, 138, 184, 27], 
            right: [16, 24, 93, 38, 2, 59, 54, 16, 206, 183, 217, 245, 125, 73, 210, 179, 135, 99, 161, 43, 43, 189, 250, 147, 39, 90, 255, 24, 42, 251, 149, 220], 
            parent: [181, 157, 35, 221, 161, 240, 65, 205, 125, 210, 142, 58, 147, 55, 148, 56, 221, 206, 216, 118, 104, 90, 130, 87, 219, 62, 104, 251, 27, 201, 113, 211], 
            parent_depth: 2, 
            parent_index: 1, 
            flush_left: false, 
            flush_right: true 
        }, 
        MerklePathEvent { 
            root_id: 0, 
            left: [246, 247, 101, 36, 57, 192, 24, 48, 162, 208, 160, 30, 187, 154, 180, 176, 208, 104, 135, 216, 175, 8, 0, 249, 96, 50, 194, 72, 102, 219, 184, 27], 
            right: [181, 157, 35, 221, 161, 240, 65, 205, 125, 210, 142, 58, 147, 55, 148, 56, 221, 206, 216, 118, 104, 90, 130, 87, 219, 62, 104, 251, 27, 201, 113, 211], 
            parent: [124, 166, 97, 100, 173, 242, 98, 95, 141, 158, 147, 144, 202, 239, 150, 192, 0, 99, 9, 138, 61, 19, 65, 163, 160, 4, 227, 66, 233, 115, 199, 3], 
            parent_depth: 1, 
            parent_index: 0, 
            flush_left: false, 
            flush_right: true 
        }
    ]
    

In these cases the nodes that have to be pulled are the right children:  
![image](/images/external/S19_AiY7ge.png)

![image](/images/external/ByT3DLk4gg.png)

Finally, you'll find a print of a both left and right event:
    
    Both events: [
        MerklePathEvent { 
            root_id: 0, 
            left: [124, 166, 97, 100, 173, 242, 98, 95, 141, 158, 147, 144, 202, 239, 150, 192, 0, 99, 9, 138, 61, 19, 65, 163, 160, 4, 227, 66, 233, 115, 199, 3], 
            right: [70, 219, 30, 17, 251, 21, 8, 37, 23, 248, 120, 106, 49, 210, 42, 247, 15, 227, 231, 151, 101, 7, 187, 203, 29, 109, 186, 223, 43, 126, 183, 173], 
            parent: [193, 178, 67, 64, 61, 105, 200, 119, 129, 200, 250, 91, 108, 49, 178, 161, 234, 142, 150, 145, 206, 128, 43, 153, 216, 191, 196, 183, 198, 179, 118, 122], 
            parent_depth: 0, 
            parent_index: 0, 
            flush_left: true, 
            flush_right: true 
        }
    ]
    

In this case, if you are looking at the blue path, the right child node "70" has to be pulled, but if you are looking at the green path, the left child "124" has to be pulled. That's why this event is both left and right:  
![image](/images/external/SJV1r2tmxx.png)

## RootTable

### Purpose

`RootTable` is a table within the Binius Merkle Tree constraint system that is responsible for reconciling the final values of Merkle paths with the declared Merkle roots. While `NodesTable` verifies the steps along a path, `RootTable` provides the ultimate cryptographic guarantee that these paths lead to the correct, pre-committed Merkle roots.

### Content
    
    pub struct RootTable {
        pub id: TableId,
        pub root_id: Col<B8>,
        pub digest: [Col<B32>; 8]
    }
    

This table contains the data -the Id and the digest (or content)- of the root nodes of all the trees we are analyzing, since we can prove different paths for different trees.

### Initialization

RootTable initialization is done by its method [new()](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L469):
    
    impl RootTable {
        pub fn new(
            cs: &mut ConstraintSystem,
            nodes_channel: ChannelId,
            roots_channel: ChannelId,
        ) -> Self {
            
            /*...*/
        }
    }
    

This function:

        1. Adds a table to the `cs`:
    
    let mut table = cs.add_table("merkle_tree_roots");
    

        2. Defines columns within that table (committed and/or virtual):
    
    let root_id = table.add_committed("root_id");
    let digest = table.add_committed_multiple("digest");
    
    let zero = table.add_constant("zero", [B32::ZERO]);
    

        3. Adds the flushing rules associated with that table and its channels (`nodes_channel` and `roots_channel`).
    
    table.pull(roots_channel_id, to_root_flush(root_id_upcasted, digest));
    let mut nodes_channel = NodesChannel::new(&mut table, nodes_channel_id);
    nodes_channel.pull(root_id_upcasted, digest, zero, zero);
    

### Flushing Rules

`RootTable` primarily interacts with the `nodes_channel` and `roots_channel` to perform its reconciliation. It will `pull` data from both channels to verify consistency.

        * **`nodes_channel`** : This channel carries information about all intermediate and final nodes of the Merkle paths. `RootTable` will `pull` the digest of the final node of a path from this channel.
        * **`roots_channel`** : This channel contains the actual Merkle roots that are being proven against. `RootTable` will `pull` these values to ensure that the path's end-point matches one of the valid roots.

The flushing rules would ensure that the necessary data (final path node digests and declared root digests) are available to the `RootTable` for its internal consistency checks. This comparison forms the core of the zero-knowledge constraint for root verification, ensuring that the Merkle path indeed leads to the claimed root.

## IncrLookup

### Purpose

Beyond `NodesTable` and `RootTable`, the Binius Merkle Tree constraint system also utilizes [IncrLookup](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/indexed_lookup/incr.rs#L161). This is a specialized gadget designed to efficiently verify 8-bit increment operations with a carry bit. Instead of writing complex arithmetic constraints for each instance of an increment operation, `IncrLookup` allows the prover to simply demonstrate that each operation performed is present in a pre-defined table of all valid increment results. This significantly reduces the computational cost and proof size.

In the specific context of Merkle tree inclusion proofs, `IncrLookup` is used to ensure that in each `MerklePathEvent`, the child's depth is exactly one greater than the parent's depth.

### Content

The [IncrLookup](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/indexed_lookup/incr.rs#L161) only has two columns `entries_ordered` and `entries_sorted`. Both columns have exactly the same values but sorted in different ways. We'll see how these columns are filled later on.

The struct `IncrLookup` has one more field `lookup_producer`. [LookupProducer](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/lookup.rs#L16) is the gadget in charge of creating the lookup table.

### Initialization

When the `MerkleTreeCS` is set up, an `IncrLookup` instance is created (see [here](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L87)) through its method [new()](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/indexed_lookup/incr.rs#L176), which does the following:

        1. Fixes the size for the columns:
    
    table.require_fixed_size(IncrIndexedLookup.log_size());
    

Note that `IncrIndexedLookup.log_size()` is $2^9 = 512$ as you can see [here](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/indexed_lookup/incr.rs#L245). This is because each index $i \in {0, \ldots, 511}$ of the column will represent an incrementation of some certain input. The 8 less significant bits of $i$ tell us the input and the most significant bit tell us the carry.

        2. Adds the `entries_ordered` and `entries_sorted` columns to the table.

        3. Adds **flushing rules** for the `permutation_channel` of our constraint system to ensure that one column is the permutation of the other one:
    
    // Use flush to check that entries_sorted is a permutation of entries_ordered.
    table.push(permutation_chan, [entries_ordered]);
    table.pull(permutation_chan, [entries_sorted]);
    

        4. Configures a `LookupProducer` to manage how entries are queried and to handle their multiplicities (how many times each specific increment operation occurs during the proof).

### Table population

As well as the other tables, the `incr_table` of the `MerkleTreeCS` is filled inside the function [fill_tables()](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L100), specifically in this part:
    
    let lookup_counts = tally(cs, witness, &[], self.lookup_channel, &IncrIndexedLookup)?;
    
    // Fill the lookup table with the sorted counts
    let sorted_counts = lookup_counts
        .into_iter()
        .enumerate()
        .sorted_by_key(|(_, count)| Reverse(*count))
        .collect::<Vec<_>>();
    witness.fill_table_parallel(&self.incr_table, &sorted_counts)?;
    

Let's break down this code snippet in detail. For that, we have to understand what is the variable `lookup_counts` and what does the function `tally()` do.

#### Lookup Counts

`lookup_counts` is a vector of 512 integer elements. This vector is the result of the function [tally()](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/builder/indexed_lookup.rs#L51). As its documentation explains, this function "determines the read counts of each entry in an indexed lookup table". It iterates over every table of our constraint system looking for a specific flushing rule: a pull operation on the input channel. In our case, the input channel is called `lookup_channel`. Whenever it finds this flushing rule it adds 1 to the result vector at a specific index (that depends on the value being pulled).

To understand how this index is chosen let's add some prints and see what happens in our example.
    
    pub fn tally<P>(
    	cs: &ConstraintSystem<B128>,
    	// TODO: This doesn't actually need mutable access. But must of the WitnessIndex methods only
    	// allow mutable access.
    	witness: &mut WitnessIndex<P>,
    	boundaries: &[Boundary<B128>],
    	chan: ChannelId,
    	indexed_lookup: &impl IndexedLookup<B128>,
    ) -> Result<Vec<u32>, Error>
    where
    	P: PackedField<Scalar = B128>
    		+ PackedExtension<B1>
    		+ PackedExtension<B8>
    		+ PackedExtension<B16>
    		+ PackedExtension<B32>
    		+ PackedExtension<B64>
    		+ PackedExtension<B128>,
    {
    	println!("------- Look up counts for channel: {chan} -------");
    	let mut counts = vec![0; 1 << indexed_lookup.log_size()]; // 2^{8+1} 
    
    	// Tally counts from the tables
    	for table in &cs.tables {
    		// In merkle tree example, NodesTable and RootTable
    		if let Some(table_index) = witness.get_table(table.id()) {
    			println!("--- Processing table: {} (ID: {}) ---", table.name, table.id());
    			for partition in table.partitions.values() {
    				for flush in &partition.flushes {
    					if flush.channel_id == chan && flush.direction == FlushDirection::Pull {
    						// In the merkle tree example, this occurs in every NodesTable pull from the
    						// lookup_channel.
    						println!(
    							"Found matching flush: The table has a Pull operation on channel {}",
    							chan
    						);
    
    						let table_size = table_index.size();
    						// TODO: This should be parallelized, which is pretty tricky.
    						let segment = table_index.full_segment();
    						let cols = flush
    							.columns
    							.iter()
    							.map(|&col_index| segment.get_dyn(col_index))
    							.collect::<Result<Vec<_>, _>>()?;
    
    						if !flush.selectors.is_empty() {
    							// TODO: check flush selectors
    							todo!("tally does not support selected table reads yet");
    						}
    
    						let mut elems = vec![B128::ZERO; cols.len()];
    						// It's important that this is only the unpacked table size(rows * values
    						// per row in the partition), not the full segment size. The entries
    						// after the table size are not flushed.
    						for i in 0..table_size * partition.values_per_row {
    							for (elem, col) in iter::zip(&mut elems, &cols) {
    								*elem = col.get(i);
    							}
    							let index = indexed_lookup.entry_to_index(&elems);
    							println!("Index {index} corresponds to element: {:?}", elems);
    							counts[index] += 1;
    						}
    					}
    				}
    			}
    		}
    	}
    

This should print at first the following:
    
    ------- Look up counts for channel: 2 -------
    --- Processing table: merkle_tree_nodes_left (ID: 0) ---
    Found matching flush: The table has a Pull operation on channel 2
    Index 258 corresponds to element: [BinaryField128b(0x00000000000000000000000000010302)]
    Index 257 corresponds to element: [BinaryField128b(0x00000000000000000000000000010201)]
    

This tells us this information: We are looking for pull outs on the channel 2 (the `lookup_channel`), and we analize first the `NodesTable` that has the _left events_. In that table it encountered two pull outs from the channel:

        1. The first pull out is  
`BinaryField128b(0x00000000000000000000000000010302)`. To understand what this binary field element represent follow this steps: 
           * convert its hex value to a binary expansion:  
$$0\text{x}10302 = 00010000001100000010$$
           * Take the 8 less significant bits. The resulting number is called _input_ : $00000010$.
           * Take the bit at position 16 (from LSB to MSB and starting in 0). The resulting number is called _carry in_ : $1$
           * Concatenate them in the following way: _carry in_ || _input_. This results in  
$$100000010.$$
           * The result is the binary expansion of our index:  
$$100000010 = 258.$$

Now, what is has to do all of this with our Merkle tree? Well, this index $258$ is representing the parent's and children's depths in the following event:  
![image](/images/external/ryf9s5lEgl.png)

Since the parent's depth is 2, the input will be $00000010$. And since the children depth is the parent's plus one, the carry is $1$. You can see this better at the initialization of every `NodesTable` ([here](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L249)), in this specific part:
    
    let parent_depth = table.add_committed("parent_depth");
    
    let one = table.add_constant("one", [B1::ONE]);
    
    let increment = Incr::new(&mut table, lookup_chan, parent_depth, one);
    let child_depth = increment.output;
    

Here the `input` is `parent_depth`and the `carry_in` is `one`.

        2. The second pull out is `BinaryField128b(0x00000000000000000000000000010201)`. Let's do the same thing we did above: 
           * Convert to binary: $$0\text{x}10201 = 00010000001000000001$$
           * Then, `input = 00000001`. This means that it represent an event with parent's depth 1.
           * `carry_in = 1` because children's depth is parent's depth plus 1.
           * Concatenate to get the index: $100000001 = 257$.  
This index corresponds to the following event:  
![image](/images/external/Skm17oe4ll.png)

Now, let's see what else the function `tally()` printed. You should also see this:
    
    --- Processing table: merkle_tree_nodes_right (ID: 1) ---
    Found matching flush: The table has a Pull operation on channel 2
    Index 257 corresponds to element: [BinaryField128b(0x00000000000000000000000000010201)]
    Index 258 corresponds to element: [BinaryField128b(0x00000000000000000000000000010302)]
    

Note that we have here the same indeces as before. That's because the right events have the same parent depths as the left ones:  
![image](/images/external/SkTU7oxNeg.png)

After that you should see in your terminal the following:
    
    --- Processing table: merkle_tree_nodes_both (ID: 2) ---
    Found matching flush: The table has a Pull operation on channel 2
    Index 256 corresponds to element: [BinaryField128b(0x00000000000000000000000000010100)]
    

Here, note that $$0\text{x}10100 = 00010000000100000000.$$ Then, `input = 00000000` and that means parent's depth is 0. The index $256 = 100000000$ is representing this both left and right event:  
![image](/images/external/rkTmBjxElx.png)

Finally, you should see printed the following:
    
    --- Processing table: merkle_tree_roots (ID: 3) ---
    

This means that it processed the roots table but, as expected, it didn't find any pull out from the lookup channel.

#### Sorted counts

Recall that we were trying to understand how the `incr_table` is populated. After calculating all the `lookup_counts`, we sort them in a specific way, store it in `sorted_counts` and use it to fill the table.

The variable `sorted_counts` is a vector of 512 tuples. The first element of each tuple is an index and the second element has the count that the variable `lookup_counts`has at that index. These tuples are sorted according to counts from highest to lowest. One more time let's add this print at the function [fill_tables()](https://github.com/IrreducibleOSS/binius/blob/main/crates/m3/src/gadgets/merkle_tree/mod.rs#L100) to understand it better:
    
    let lookup_counts = tally(cs, witness, &[], self.lookup_channel, &IncrIndexedLookup)?;
    
    // Fill the lookup table with the sorted counts
    let sorted_counts = lookup_counts
        .into_iter()
        .enumerate()
        .sorted_by_key(|(_, count)| Reverse(*count))
        .collect::<Vec<_>>();
    
    println!("------- Increment Table -------");
    println!("Sorted counts: {sorted_counts:?}");
    
    witness.fill_table_parallel(&self.incr_table, &sorted_counts)?;
    

This should print:
    
    ------- Increment Table -------
    Sorted counts: [
        (257, 2), (258, 2), (256, 1), (0, 0), (1, 0), (2, 0), ..., (510, 0), (511, 0)
    ]
    

The `IncrLookup` instance uses these counts to fill its internal `entries_ordered` and `entries_sorted` columns, and its `LookupProducer` records the exact multiplicity for each valid increment operation that occurred in the Merkle tree paths computation.

## Summary

This post offers an in-depth exploration of Binius’s M3 arithmetization framework, using a Merkle tree inclusion proof as a concrete example. We examined how tables and channels serve as the foundational abstractions in M3, replacing the traditional concept of a sequential execution trace with a declarative, data-driven model. In this paradigm, computation is decomposed into modular tables, while global consistency is maintained through channel balancing.

At the core of the example lies the `MerkleTreeCS` gadget, which coordinates five specialized tables and multiple channels to verify Merkle path correctness. The `NodesTable` handles the hashing of parent-child node relationships, the `RootTable` ties computed paths to expected root values, and the `IncrLookup` table validates depth transitions using a permutation-checked lookup structure. These components communicate via channels like `nodes_channel` and `lookup_channel`, ensuring that every consumed value was properly produced and accounted for.
