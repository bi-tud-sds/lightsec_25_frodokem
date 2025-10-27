////    ////////////    Copyright (C) 2025 Giuseppe Manzoni, Barkhausen Institut
////    ////////////    
////                    This source describes Open Hardware and is licensed under the
////                    CERN-OHL-W v2 (https://cern.ch/cern-ohl)
////////////    ////    
////////////    ////    
////    ////    ////    
////    ////    ////    
////////////            Authors:
////////////            Giuseppe Manzoni (giuseppe.manzoni@barkhauseninstitut.org)


`ifndef MAIN_CORE_V
`define MAIN_CORE_V


// This file provides the module: main_core
// It contains the main module, with the exception of the controller, which is handled separately to ease the testing.


`include "adapted_keccak.v"
`include "busHubAndAdapters.v"
`include "memAndMul.v"
`include "seedAStorage.v"


`define CmdHubCMD_outer     4'b1000
`define CmdHubCMD_keccak    4'b0100
`define CmdHubCMD_memAndMul 4'b0010
`define CmdHubCMD_seedA     4'b0001

`define CmdHubCMD_SIZE  8



`define MainCoreCMD_NO_o_in  {`OuterInCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_o_out {`OuterOutCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_k_in  {`KeccakInCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_k_out {`KeccakOutCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_h     {`CmdHubCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_m     {`MemAndMulCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_k     {`KeccakAdaptedCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_s     {`SeedAStorageCMD_SIZE{1'b0}}

//                          15                   15                11                  2                       8                  7                    14                       1
`define MainCoreCMD_SIZE  (`OuterInCMD_SIZE + `OuterOutCMD_SIZE + `KeccakInCMD_SIZE + `KeccakOutCMD_SIZE + `CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE + `SeedAStorageCMD_SIZE)


`define MainCoreCMD_which_o_in   (8'b1 << 0)
`define MainCoreCMD_which_o_out  (8'b1 << 1)
`define MainCoreCMD_which_k_in   (8'b1 << 2)
`define MainCoreCMD_which_k_out  (8'b1 << 3)
`define MainCoreCMD_which_h      (8'b1 << 4)
`define MainCoreCMD_which_m      (8'b1 << 5)
`define MainCoreCMD_which_k      (8'b1 << 6)
`define MainCoreCMD_which_s      (8'b1 << 7)

`define MainCoreCMD_which_SIZE  8

//                                   8                       3                   3                        3                    3
`define MainCoreCONF_SIZE   (`MemCONF_matrixNumBlocks_size + `SamplerCONF_SIZE + `MemCONF_lenSec_size + `MemCONF_lenSE_size + `MemCONF_lenSalt_size)



module main_core(
    // o_in:  { size:15bits }
    // o_out: { size:15bits }
    // k_in:  { byteVal:8bits, skipIsLast:1bit, CMD:2bit } 
    // k_out: { skipIsLast:1bit, sample:1bit }
    // h:     { destination:4bit, source:4bit }  each is: { outer:1bit, keccak:1bit, memAndMul:1bit, seedA:1bit } 
    // m:     { isPack:1bit, mainCmd:6bit }
    // k:     { is128else256:1bit, inState:1bit, outState:1bit, mainIsInElseOut:1bit, mainNumBlocks:9bits, secondaryNumBlocks:1bits }
    // s:     { cmd_startIn:1bit, cmd_startOut:1bit }
    input [`MainCoreCMD_SIZE-1:0] cmd,
    input [`MainCoreCMD_which_SIZE-1:0] cmd_hasAny,
    output cmd_consume,

    input [64-1:0] in,
    input in_isReady,
    output in_canReceive,

    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,

    input [`MainCoreCONF_SIZE-1:0] conf, // { The FrodoKEM parameter/8 : 8bits, which sampling distribution : 3bits, which lenSec : 3bits, which lenSE : 3bits, which lenSalt : 3bits }.   distr 0,1 have max FrodoKEM param of 1344.  distr 2 has max FrodoKEM param of 1330.

    input rst,
    input clk
  );
  wor ignore;

  wire [`MemCONF_matrixNumBlocks_size-1:0] config_matrixNumBlocks;
  wire [`SamplerCONF_SIZE-1:0] config_whichSampling;
  wire [`MemCONF_lenSec_size-1:0] config_lenSec;
  wire [`MemCONF_lenSE_size-1:0] config_lenSE;
  wire [`MemCONF_lenSalt_size-1:0] config_lenSalt;

  assign {config_matrixNumBlocks, config_whichSampling, config_lenSec, config_lenSE, config_lenSalt} = conf;


  wire config_SUseHalfByte = config_whichSampling[2];

  wire o_in__cmd_canReceive;
  wire o_out__cmd_canReceive;
  wire k_in__cmd_canReceive;
  wire k_out__cmd_canReceive;
  wire h__cmd_canReceive;
  wire m__cmd_canReceive;
  wire k__cmd_canReceive;
  wire s__cmd_canReceive;
  assign cmd_consume = ((cmd_hasAny & `MainCoreCMD_which_o_in) == 0 | o_in__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_o_out) == 0 | o_out__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_k_in) == 0 | k_in__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_k_out) == 0 | k_out__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_h) == 0 | h__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_m) == 0 | m__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_k) == 0 | k__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_s) == 0 | s__cmd_canReceive)
                     & cmd_hasAny != 0;

  wire o_in__cmd_isReady  = (cmd_hasAny & `MainCoreCMD_which_o_in) != 0 & o_in__cmd_canReceive & cmd_consume;
  wire o_out__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_o_out) != 0 & o_out__cmd_canReceive & cmd_consume;
  wire k_in__cmd_isReady  = (cmd_hasAny & `MainCoreCMD_which_k_in) != 0 & k_in__cmd_canReceive & cmd_consume;
  wire k_out__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_k_out) != 0 & k_out__cmd_canReceive & cmd_consume;
  wire h__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_h) != 0 & h__cmd_canReceive & cmd_consume;
  wire m__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_m) != 0 & m__cmd_canReceive & cmd_consume;
  wire k__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_k) != 0 & k__cmd_canReceive & cmd_consume;
  wire s__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_s) != 0 & s__cmd_canReceive & cmd_consume;

  wire [`OuterInCMD_SIZE-1:0] o_in__cmd    = cmd[`OuterOutCMD_SIZE + `KeccakInCMD_SIZE + `KeccakOutCMD_SIZE + `CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE + `SeedAStorageCMD_SIZE +:`OuterInCMD_SIZE];
  wire [`OuterOutCMD_SIZE-1:0] o_out__cmd  = cmd[`KeccakInCMD_SIZE + `KeccakOutCMD_SIZE + `CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE + `SeedAStorageCMD_SIZE +:`OuterOutCMD_SIZE];
  wire [`KeccakInCMD_SIZE-1:0] k_in__cmd   = cmd[`KeccakOutCMD_SIZE + `CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE + `SeedAStorageCMD_SIZE +:`KeccakInCMD_SIZE];
  wire [`KeccakOutCMD_SIZE-1:0] k_out__cmd = cmd[`CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE + `SeedAStorageCMD_SIZE +:`KeccakOutCMD_SIZE];
  wire [`CmdHubCMD_SIZE-1:0] h__cmd        = cmd[`MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE + `SeedAStorageCMD_SIZE +:`CmdHubCMD_SIZE];
  wire [`MemAndMulCMD_SIZE-1:0] m__cmd     = cmd[`KeccakAdaptedCMD_SIZE + `SeedAStorageCMD_SIZE +:`MemAndMulCMD_SIZE];
  wire [`KeccakAdaptedCMD_SIZE-1:0] k__cmd = cmd[`SeedAStorageCMD_SIZE +:`KeccakAdaptedCMD_SIZE];
  wire [`SeedAStorageCMD_SIZE-1:0] s__cmd  = cmd[0 +:`SeedAStorageCMD_SIZE];


  wire [64*4-1:0] h__in;
  wire [4-1:0] h__in_isReady;
  wire [4-1:0] h__in_canReceive;
  wire [4-1:0] h__in_isLast_in;
  wire [4-1:0] h__in_isLast_out;
  wire [64*4-1:0] h__out;
  wire [4-1:0] h__out_isReady;
  wire [4-1:0] h__out_canReceive;
  wire [4-1:0] h__out_isLast_in;
  wire [4-1:0] h__out_isLast_out;
  busSwitch #(4) hub (
    .cmd(h__cmd),
    .cmd_isReady(h__cmd_isReady),
    .cmd_canReceive(h__cmd_canReceive),
    .allowedCMDMask(16'b1111_1011_1100_1100), // [pos_to * N + pos_from] { outer:1bit, keccak:1bit, memAndMul:1bit, seedA:1bit }
    .in(h__in),
    .in_isReady(h__in_isReady),
    .in_canReceive(h__in_canReceive),
    .in_isLast_in(h__in_isLast_in),
    .in_isLast_out(h__in_isLast_out),
    .out(h__out),
    .out_isReady(h__out_isReady),
    .out_canReceive(h__out_canReceive),
    .out_isLast_in(h__out_isLast_in),
    .out_isLast_out(h__out_isLast_out),
    .rst(rst),
    .clk(clk)
  );

  main_adapter_outer_in o_in(
    .cmd(o_in__cmd),
    .cmd_isReady(o_in__cmd_isReady),
    .cmd_canReceive(o_in__cmd_canReceive),
    .h__in(h__in[64*3+:64]),
    .h__in_isReady(h__in_isReady[3]),
    .h__in_canReceive(h__in_canReceive[3]),
    .h__in_isLast_in(h__in_isLast_in[3]),
    .h__in_isLast_out(h__in_isLast_out[3]),
    .o__in(in),
    .o__in_isReady(in_isReady),
    .o__in_canReceive(in_canReceive),
    .rst(rst),
    .clk(clk)
  );

  main_adapter_outer_out o_out(
    .cmd(o_out__cmd),
    .cmd_isReady(o_out__cmd_isReady),
    .cmd_canReceive(o_out__cmd_canReceive),
    .h__out(h__out[64*3+:64]),
    .h__out_isReady(h__out_isReady[3]),
    .h__out_canReceive(h__out_canReceive[3]),
    .h__out_isLast_in(h__out_isLast_in[3]),
    .h__out_isLast_out(h__out_isLast_out[3]),
    .o__out(out),
    .o__out_isReady(out_isReady),
    .o__out_canReceive(out_canReceive),
    .rst(rst),
    .clk(clk)
  );

  adapted_keccak keccak(
    .k_in__cmd(k_in__cmd),
    .k_in__cmd_isReady(k_in__cmd_isReady),
    .k_in__cmd_canReceive(k_in__cmd_canReceive),
    .k_out__cmd(k_out__cmd),
    .k_out__cmd_isReady(k_out__cmd_isReady),
    .k_out__cmd_canReceive(k_out__cmd_canReceive),
    .config_whichSampling(config_whichSampling),
    .k__cmd(k__cmd),
    .k__cmd_isReady(k__cmd_isReady),
    .k__cmd_canReceive(k__cmd_canReceive),
    .h__out(h__out[2*64+:64]),
    .h__out_isReady(h__out_isReady[2]),
    .h__out_canReceive(h__out_canReceive[2]),
    .h__out_isLast_in(h__out_isLast_in[2]),
    .h__out_isLast_out(h__out_isLast_out[2]),
    .h__in(h__in[2*64+:64]),
    .h__in_isReady(h__in_isReady[2]),
    .h__in_canReceive(h__in_canReceive[2]),
    .h__in_isLast_in(h__in_isLast_in[2]),
    .h__in_isLast_out(h__in_isLast_out[2]),
    .rst(rst),
    .clk(clk)
  );

  assign ignore = h__out_isLast_out[1] | h__in_isLast_out[1];
  memAndMul memAndMul(
    .cmd(m__cmd),
    .cmd_isReady(m__cmd_isReady),
    .cmd_canReceive(m__cmd_canReceive),
    .in_isReady(h__out_isReady[1]),
    .in(h__out[1*64+:64]),
    .in_canReceive(h__out_canReceive[1]),
    .in_isLast(h__out_isLast_in[1]),
    .out_isReady(h__in_isReady[1]),
    .out_isLast(h__in_isLast_in[1]),
    .out(h__in[1*64+:64]),
    .out_canReceive(h__in_canReceive[1]),
    .config_matrixNumBlocks(config_matrixNumBlocks),
    .config_SUseHalfByte(config_SUseHalfByte),
    .config_lenSec(config_lenSec),
    .config_lenSE(config_lenSE),
    .config_lenSalt(config_lenSalt),
    .rst(rst),
    .clk(clk)
  );

  assign ignore = h__out_isLast_out[0] | h__in_isLast_out[0];
  seedAStorage seedA(
    .cmd(s__cmd),
    .cmd_isReady(s__cmd_isReady),
    .cmd_canReceive(s__cmd_canReceive),
    .in(h__out[0*64+:64]),
    .in_isReady(h__out_isReady[0]),
    .in_isLast(h__out_isLast_in[0]),
    .in_canReceive(h__out_canReceive[0]),
    .out(h__in[0*64+:64]),
    .out_isReady(h__in_isReady[0]),
    .out_isLast(h__in_isLast_in[0]),
    .out_canReceive(h__in_canReceive[0]),
    .rst(rst),
    .clk(clk)
  );
endmodule


`endif // MAIN_CORE_V
