
# LightSEC 2025 FrodoKEM

This is a verilog implementation of the FrodoKEM algorithm for a paper submitted to LightSEC 2025 conference.

It has a single module (in src/main.v) that can be configured to run the three FrodoKEM schemes FrodoKEM-{640,976,1344}-SHAKE. More specifically, the module can be configured to run any of the three algorithms of FrodoKEM: Key generation, encapsulation and decapsulation. It executes those algorithms one at a time. See the related paper (to appear at Springer soon) for more information on the FrodoKEM algorithm and on the implementation structure.

## Code Conventions

We use the prefix `o_` for output ports, `i_` for input ports. We use the suffix `__d1` and `__d2` for a signal delayed by one or two clock cycles.

There are two types of bus. The main one has a `canReceive` wire to say if the receiving module can receive data, a `isReady` wire to say that the data is ready, and which can only be set if the `canReceive` is also set. The second type of bus has a `hasAny` to say if the bus has data, and a `consume` that is set by the receiver when they took note of that data. Both can have a `isLast` wire to say if the data stream is ended. 

See the main test file (at test/testAll.v) for information on the usage.

## Implementation

The code targets the AMD/Xilinx Artix-7 FPGA xc7a35Tcsg324-3, and a clock cycle of 62.5 MHz. It uses the following resources:

Element | #
--- | ---:
LUTs | 19082
FFs | 5331
BRAMs | 8
DSPs | 0
Slice Equivalents | 6366.5

The current timing analysis has the following slack times:

Slack type | time (ns)
--- | ---:
Setup | 0.160
Hold | 0.111
PW | 7.500

The execution time of the supported run-time configurations are:

algorithm | parameter | clock cycles | Area/Throughput
--- | ---: | ---: | ---:
keygen | 640 | 133397 | 13.588
encaps | 640 | 136427 | 13.897
decaps | 640 | 139164 | 14.176
keygen | 976 | 298264 | 30.382
encaps | 976 | 303504 | 30.916
decaps | 976 | 307413 | 31.314
keygen | 1344 | 539695 | 54.975
encaps | 1344 | 546865 | 55.706
decaps | 1344 | 552189 | 56.248


