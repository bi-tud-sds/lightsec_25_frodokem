
# LightSEC 2025 FrodoKEM

This is a verilog implementation of the FrodoKEM algorithm for a paper submitted to LightSEC 2025 conference.

It has a single module (in src/main.v) that can be configured to run the three FrodoKEM schemes FrodoKEM-{640,976,1344}-SHAKE. More specifically, the module can be configured to run any of the three algorithms of FrodoKEM: Key generation, encapsulation and decapsulation. It executes those algorithms one at a time. See the related paper (to appear at Springer soon) for more information on the FrodoKEM algorithm and on the implementation structure.

## Code Conventions

We use the prefix `o_` for output ports, `i_` for input ports. We use the suffix `__d1` and `__d2` for a signal delayed by one or two clock cycles.

There are two types of bus. The main one has a `canReceive` wire to say if the receiving module can receive data, a `isReady` wire to say that the data is ready, and which can only be set if the `canReceive` is also set. The second type of bus has a `hasAny` to say if the bus has data, and a `consume` that is set by the receiver when they took note of that data. Both can have a `isLast` wire to say if the data stream is ended. 

See the main test file (at test/testAll.v) for information on the usage.

## Important Note

As we were further optimizing the code, we discovered that there is probably a bug in the implemented design we used to obtain the number of resources utilized and the clock frequency.

More specifically, while this design passes all tests even with a post-implementation functional simulation, we believe that the implemented design did not contain all the logic present in the source code. For this reason we added a new branch to this repository, 'update1'. As you can see from the results reported there, a relatively small optimization caused a +40% in size, and +60% clock period. We believe those results to be more representative of the true size of this module.

Yet, even with those results, we believe this implementation is an improvement over the previous work [1].

The authors of [1] provide six distinct modules: two modules (the parameter sets 640 and 976) for every operation of FrodoKEM (key generation, encapsulation, decapsulation). For the common case of a server, this would require multiple modules, so in our design we provide a single module that can execute all those operations, one at a time, with a number of operations per second of 9X-9.7X that of [1], depending on the operations. Additionally, our module supports the 1344 parameter set. The cost for doing this unification is a ~21% size increase compared to the biggest module of [1], but, overall, our area to throughput ratio decreased by ~65%-88% compared to [1].

[1] Howe, J., Oder, T., Krausz, M., Güneysu, T.: Standard Lattice-Based Key Encapsulation on Embedded Devices. IACR Transactions on Cryptographic Hardware and Embedded Systems 2018(3), 372–393 (2018). https://doi.org/10.13154/tches.v2018.i3.372-393

