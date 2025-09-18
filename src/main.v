`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/08/2025 04:12:12 PM
// Design Name: 
// Module Name: main
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`include "main_core.v"


`define MainCMD_keygen       3'd0
`define MainCMD_encaps       3'd1
`define MainCMD_decaps       3'd2
`define MainCMD_setupTest    3'd3
`define MainCMD_addEntropy   3'd4
`define MainCMD_setParam640  3'd5
`define MainCMD_setParam976  3'd6
`define MainCMD_setParam1344 3'd7

`define MainCMD_SIZE  3





`define MainExpCMD_generic     4'd0
`define MainExpCMD_ki_byte     4'd1
`define MainExpCMD_ki_zeros    4'd2
`define MainExpCMD_k_single    4'd3
`define MainExpCMD_k_longOut   4'd4
`define MainExpCMD_k_longIn    4'd5
`define MainExpCMD_k_outState  4'd6
`define MainExpCMD_k_inState   4'd7
`define MainExpCMD_k_noOverlap 4'd8
`define MainExpCMD_m           4'd9
`define MainExpCMD_genA_kOut   4'd10
`define MainExpCMD_genA_kOut_DBG 4'd11

`define MainExpCMD_SIZE  4


// Inner Outer

module command_expansion(
    input [`MainExpCMD_SIZE-1:0] o,

    input o__k_isLast,
    input o__k_isSampled,
    input [9-1:0] o__param,
    input [6-1:0] o__m_cmd,
    input o__m_isPack,
    // k2o is 4 words
    // o2k is 16 words
    input [4-1:0] o__h_dst,
    input [4-1:0] o__h_src,

    input o_hasAny,
    output o_consume, // the i/o could still be ongoing.

    output [`MainCoreCMD_SIZE-1:0] i,
    output [`MainCoreCMD_which_SIZE-1:0] i_hasAny,
    input i_consume,
    
    input config_useShake128
  );

  wire [4-1:0] o__h_either = o__h_src | o__h_dst;

  assign o_consume = i_consume;

  wire [`MainCoreCMD_which_SIZE-1:0] i_hasAny__raw;
  wire hasNone = {`MainCoreCMD_which_SIZE{1'b0}};
  assign i_hasAny = o_hasAny ? i_hasAny__raw : hasNone;

  assign i_hasAny__raw = o == `MainExpCMD_genA_kOut ? `MainCoreCMD_which_k | `MainCoreCMD_which_h | `MainCoreCMD_which_k_out
`ifdef OUTPUT_INTERNALS_FOR_TEST
                       : o == `MainExpCMD_genA_kOut_DBG ? `MainCoreCMD_which_k | `MainCoreCMD_which_h | `MainCoreCMD_which_k_out | `MainCoreCMD_which_o_out
`endif
                       : ((o__h_dst & `CmdHubCMD_keccak) != 0         ? `MainCoreCMD_which_k_in : hasNone)
                       | ((o__h_src & `CmdHubCMD_keccak) != 0         ? `MainCoreCMD_which_k_out : hasNone)
                       | ((o__h_dst & `CmdHubCMD_outer) != 0          ? `MainCoreCMD_which_o_out : hasNone)
                       | ((o__h_src & `CmdHubCMD_outer) != 0          ? `MainCoreCMD_which_o_in : hasNone)
                       | ((o__h_either & `CmdHubCMD_memAndMul) != 0   ? `MainCoreCMD_which_m : hasNone)
                       | ((o__h_either & `CmdHubCMD_seedA) != 0       ? `MainCoreCMD_which_s : hasNone)
                       | (o__h_either != 0                            ? `MainCoreCMD_which_h : hasNone)
                       | (o == `MainExpCMD_ki_byte  || o == `MainExpCMD_ki_zeros ? `MainCoreCMD_which_k_in : hasNone)
                       | (o == `MainExpCMD_k_single || o == `MainExpCMD_k_longOut || o == `MainExpCMD_k_longIn || o == `MainExpCMD_k_outState || o == `MainExpCMD_k_inState || o == `MainExpCMD_k_noOverlap ? `MainCoreCMD_which_k : hasNone)
                       | (o == `MainExpCMD_m         ? `MainCoreCMD_which_m : hasNone);

  assign i = {
    // o_in
    o__h_dst == `CmdHubCMD_keccak && o__h_src == `CmdHubCMD_outer ?  { 6'd0, o__param } : 15'd0,
    // o_out
    o__h_dst == `CmdHubCMD_outer && o__h_src == `CmdHubCMD_keccak ? { 6'd0, o__param } : 15'd0,
    // k_in
    o__param[0+:8],
    ~o__k_isLast,
      o == `MainExpCMD_ki_byte  ? `KeccakInCMD_sendByte
    : o == `MainExpCMD_ki_zeros ? `KeccakInCMD_sendZeros
                                : `KeccakInCMD_forward,
    // k_out
    ~o__k_isLast,
    o__k_isSampled,
    // h
    o__h_dst,
    o__h_src,
    // m
    o__m_isPack,
    o__m_cmd,
    //  k
       (o == `MainExpCMD_genA_kOut   ? {4'b1000, o__param, 1'b1}    : 13'b0)
`ifdef OUTPUT_INTERNALS_FOR_TEST
     | (o == `MainExpCMD_genA_kOut_DBG ? {4'b1000, o__param, 1'b1}    : 13'b0)
`endif
     | (o == `MainExpCMD_k_single    ? {config_useShake128, 3'b000, 9'd1, 1'b1}     : 13'b0)
     | (o == `MainExpCMD_k_longIn    ? {config_useShake128, 3'b001, o__param, 1'b1} : 13'b0)
     | (o == `MainExpCMD_k_longOut   ? {config_useShake128, 3'b000, o__param, 1'b1} : 13'b0)
     | (o == `MainExpCMD_k_outState  ? {config_useShake128, 3'b011, o__param, 1'b0} : 13'b0)
     | (o == `MainExpCMD_k_inState   ? {config_useShake128, 3'b101, o__param, 1'b1} : 13'b0)
     | (o == `MainExpCMD_k_noOverlap ? {4'b0000, 9'd0, 1'b0}     : 13'b0),
    // s
    | (o__h_dst & `CmdHubCMD_seedA)
  };
endmodule


`define MainSeqCMD_genA_iter         0
`define MainSeqCMD_keygen_PRNG       1
`define MainSeqCMD_keygen_noPRNG     2
`define MainSeqCMD_keygen_mid        3
`define MainSeqCMD_keygen_postGenA   4
`define MainSeqCMD_encaps_prePRNG    5
`define MainSeqCMD_encaps_PRNG       6
`define MainSeqCMD_encaps_mid        7
`define MainSeqCMD_encaps_postGenA   8
`define MainSeqCMD_decaps_preGenA    9
`define MainSeqCMD_decaps_mid        10
`define MainSeqCMD_decaps_PRNG       11
`define MainSeqCMD_decaps_postPRNG   12
`define MainSeqCMD_setupTest         13
`define MainSeqCMD_addEntropy        14

`define MainSeqCMD_SIZE  4


// Inner Outer

`ifndef OUTPUT_INTERNALS_FOR_TEST
`define CMD_SEQ_NUM_STATES 26
`else 
`define CMD_SEQ_NUM_STATES 29
`endif

module command_sequences(
    input [`MainSeqCMD_SIZE-1:0] o,
    input o_isReady,
    output o_canReceive,
    input [16-1:0] o__genA__counter,

    output [`MainExpCMD_SIZE-1:0] i,
    output i__k_isLast,
    output i__k_isSampled,
    output [9-1:0] i__param,
    output [6-1:0] i__m_cmd,
    output i__m_isPack,
    output [4-1:0] i__h_dst,
    output [4-1:0] i__h_src,
    output i_hasAny,
    input i_consume, // the i/o could still be ongoing.

    input [3-1:0] config_frodoParam,
    
    input rst,
    input clk
  );

  wire [`MainSeqCMD_SIZE-1:0] oCurr__d1;
  wire [`MainSeqCMD_SIZE-1:0] oCurr = o_isReady ? o : oCurr__d1;
  delay #(`MainSeqCMD_SIZE) oCurr__ff (oCurr, oCurr__d1, rst, clk);

  wire [`CMD_SEQ_NUM_STATES-1:0] state;

  wire [$clog2(`CMD_SEQ_NUM_STATES+1)-1:0] state__numStates = (oCurr == `MainSeqCMD_genA_iter ? 4 : 0)
                                | (oCurr == `MainSeqCMD_keygen_PRNG ? 10 : 0)
                                | (oCurr == `MainSeqCMD_keygen_noPRNG ? 1 : 0)
                                | (oCurr == `MainSeqCMD_keygen_mid ? 10 : 0)
`ifndef OUTPUT_INTERNALS_FOR_TEST
                                | (oCurr == `MainSeqCMD_keygen_postGenA ? 6 : 0)
`else
                                | (oCurr == `MainSeqCMD_keygen_postGenA ? 7 : 0)
`endif
                                | (oCurr == `MainSeqCMD_encaps_prePRNG ? 4 : 0)
                                | (oCurr == `MainSeqCMD_encaps_PRNG ? 10 : 0)
                                | (oCurr == `MainSeqCMD_encaps_mid ? 17 : 0)
                                | (oCurr == `MainSeqCMD_encaps_postGenA ? 9 : 0)
`ifndef OUTPUT_INTERNALS_FOR_TEST
                                | (oCurr == `MainSeqCMD_decaps_preGenA ? 26 : 0)
                                | (oCurr == `MainSeqCMD_decaps_mid ? 7 : 0)
`else
                                | (oCurr == `MainSeqCMD_decaps_preGenA ? 29 : 0)
                                | (oCurr == `MainSeqCMD_decaps_mid ? 9 : 0)
`endif                                
                                | (oCurr == `MainSeqCMD_decaps_PRNG ? 5 : 0)
                                | (oCurr == `MainSeqCMD_decaps_postPRNG ? 3 : 0)
                                | (oCurr == `MainSeqCMD_setupTest ? 4 : 0)
                                | (oCurr == `MainSeqCMD_addEntropy ? 5 : 0);
  counter_bus_state #(.MAX_NUM_STEPS(`CMD_SEQ_NUM_STATES)) state__counter (
    .restart(o_isReady),
    .numStates(state__numStates),
    .canRestart(o_canReceive),
    
    .hasAny(i_hasAny),
    .state(state),
    .consume(i_consume),

    .rst(rst),
    .clk(clk)
  );

  wire [9-1:0] config_lenSec = config_frodoParam[2] ? 9'd4 : config_frodoParam[1] ? 9'd3 : 9'd2;


  reg [`MainExpCMD_SIZE-1:0] i__r;
  reg i__k_isLast__r;
  reg i__k_isSampled__r;
  reg [9-1:0] i__param__r;
  reg [6-1:0] i__m_cmd__r;
  reg i__m_isPack__r;
  reg [4-1:0] i__h_dst__r;
  reg [4-1:0] i__h_src__r;
  assign i = i__r;
  assign i__k_isLast = i__k_isLast__r;
  assign i__k_isSampled = i__k_isSampled__r;
  assign i__param = i__param__r;
  assign i__m_cmd = i__m_cmd__r;
  assign i__h_dst = i__h_dst__r;
  assign i__h_src = i__h_src__r;
  assign i__m_isPack = i__m_isPack__r;

`define SET_CMD__IS_LAST  1'b1
`define SET_CMD__NOT_LAST  1'b0
`define SET_CMD__IS_SAMPLED  1'b1
`define SET_CMD__NOT_SAMPLED  1'b0
`define SET_CMD__IS_PACKED  1'b1
`define SET_CMD__NOT_PACKED  1'b0

`define SET_CMD(cmd, k_isLast, k_isSampled, param, m_cmd, isPack, h_dst, h_src) begin \
    i__r = (cmd); \
    i__k_isLast__r = (k_isLast); \
    i__k_isSampled__r = (k_isSampled); \
    i__param__r = (param); \
    i__m_cmd__r = (m_cmd); \
    i__h_dst__r = (h_dst); \
    i__h_src__r = (h_src); \
    i__m_isPack__r = (isPack); \
  end

`define SET_CMD__NONE                           `SET_CMD(`MainExpCMD_generic,     1'b0,     1'b0,      9'b0,           5'b0,     1'b0,     4'b0,                                      4'b0)
`define SET_CMD__KI_BYTE(byte)                  `SET_CMD(`MainExpCMD_ki_byte,     1'b0,     1'b0,      {1'b0, (byte)}, 5'b0,     1'b0,     4'b0,                                      4'b0)
`define SET_CMD__KI_ZEROS(byte)                 `SET_CMD(`MainExpCMD_ki_zeros,    1'b0,     1'b0,      {1'b0, (byte)}, 5'b0,     1'b0,     4'b0,                                      4'b0)
`define SET_CMD__K_SINGLE                       `SET_CMD(`MainExpCMD_k_single,    1'b0,     1'b0,      9'b0,           5'b0,     1'b0,     4'b0,                                      4'b0)
`define SET_CMD__K_LONGIN(numCycles)            `SET_CMD(`MainExpCMD_k_longIn,    1'b0,     1'b0,      (numCycles),    5'b0,     1'b0,     4'b0,                                      4'b0)
`define SET_CMD__K_LONGOUT(numCycles)           `SET_CMD(`MainExpCMD_k_longOut,   1'b0,     1'b0,      (numCycles),    5'b0,     1'b0,     4'b0,                                      4'b0)
`define SET_CMD__K_OUTSTATE(numCycles)          `SET_CMD(`MainExpCMD_k_outState,  1'b0,     1'b0,      (numCycles),    5'b0,     1'b0,     4'b0,                                      4'b0)
`define SET_CMD__K_INSTATE(numCycles)           `SET_CMD(`MainExpCMD_k_inState,   1'b0,     1'b0,      (numCycles),    5'b0,     1'b0,     4'b0,                                      4'b0)
`define SET_CMD__K_NO_OVERLAP                   `SET_CMD(`MainExpCMD_k_noOverlap, 1'b0,     1'b0,      9'b0,           5'b0,     1'b0,     4'b0,                                      4'b0)
`define SET_CMD__GENA__KOUT(numCycles)          `SET_CMD(`MainExpCMD_genA_kOut,   1'b1,     1'b0,      (numCycles),    5'b0,     1'b0,     `CmdHubCMD_memAndMul,                      `CmdHubCMD_keccak)
`define SET_CMD__GENA__KOUT_DBG(numCycles)      `SET_CMD(`MainExpCMD_genA_kOut_DBG, 1'b1,   1'b0,      (numCycles),    5'b0,     1'b0,     `CmdHubCMD_memAndMul | `CmdHubCMD_outer,   `CmdHubCMD_keccak)
`define SET_CMD__M(memCmd)                      `SET_CMD(`MainExpCMD_m,           1'b0,     1'b0,      9'b0,           (memCmd), 1'b0,     4'b0,                                      4'b0)
`define SET_CMD__M2O(memCmd, isPack)            `SET_CMD(`MainExpCMD_generic,     1'b0,     1'b0,      9'b0,           (memCmd), (isPack), `CmdHubCMD_outer,                          `CmdHubCMD_memAndMul)
`define SET_CMD__M2K(memCmd, isLast)            `SET_CMD(`MainExpCMD_generic,     (isLast), 1'b0,      9'b0,           (memCmd), 1'b0,     `CmdHubCMD_keccak,                         `CmdHubCMD_memAndMul)
`define SET_CMD__M2KO(memCmd, isPack, isLast)   `SET_CMD(`MainExpCMD_generic,     (isLast), 1'b0,      9'b0,           (memCmd), (isPack), `CmdHubCMD_keccak | `CmdHubCMD_outer,      `CmdHubCMD_memAndMul)
`define SET_CMD__K2M(memCmd, sampled, isLast)   `SET_CMD(`MainExpCMD_generic,     (isLast), (sampled), 9'b0,           (memCmd), 1'b0,     `CmdHubCMD_memAndMul,                      `CmdHubCMD_keccak)
`define SET_CMD__K2MO(memCmd, sampled, isLast)  `SET_CMD(`MainExpCMD_generic,     (isLast), (sampled), 9'b0,           (memCmd), 1'b0,     `CmdHubCMD_memAndMul | `CmdHubCMD_outer,   `CmdHubCMD_keccak)
`define SET_CMD__K2O(numWords, sampled, isLast) `SET_CMD(`MainExpCMD_generic,     (isLast), (sampled), (numWords),     5'b0,     1'b0,     `CmdHubCMD_outer,                          `CmdHubCMD_keccak)
`define SET_CMD__K2S(isLast)                    `SET_CMD(`MainExpCMD_generic,     (isLast), 1'b0,      9'b0,           5'b0,     1'b0,     `CmdHubCMD_seedA,                          `CmdHubCMD_keccak)
`define SET_CMD__K2SO(isLast)                   `SET_CMD(`MainExpCMD_generic,     (isLast), 1'b0,      9'b0,           5'b0,     1'b0,     `CmdHubCMD_seedA | `CmdHubCMD_outer,       `CmdHubCMD_keccak)
`define SET_CMD__O2M(memCmd, isPack)            `SET_CMD(`MainExpCMD_generic,     1'b0,     1'b0,      9'b0,           (memCmd), (isPack), `CmdHubCMD_memAndMul,                      `CmdHubCMD_outer)
`define SET_CMD__O2MK(memCmd, isPack, isLast)   `SET_CMD(`MainExpCMD_generic,     (isLast), 1'b0,      9'b0,           (memCmd), (isPack), `CmdHubCMD_memAndMul | `CmdHubCMD_keccak,  `CmdHubCMD_outer)
`define SET_CMD__O2K(numWords, sampled, isLast) `SET_CMD(`MainExpCMD_generic,     (isLast), (sampled), (numWords),     5'b0,     1'b0,     `CmdHubCMD_keccak,                         `CmdHubCMD_outer)
`define SET_CMD__S2K(isLast)                    `SET_CMD(`MainExpCMD_generic,     (isLast), 1'b0,      9'b0,           5'b0,     1'b0,     `CmdHubCMD_keccak,                         `CmdHubCMD_seedA)
`define SET_CMD__O2S                            `SET_CMD(`MainExpCMD_generic,     1'b0,     1'b0,      9'b0,           5'b0,     1'b0,     `CmdHubCMD_seedA,                          `CmdHubCMD_outer)
`define SET_CMD__O2SK(isLast)                   `SET_CMD(`MainExpCMD_generic,     (isLast), 1'b0,      9'b0,           5'b0,     1'b0,     `CmdHubCMD_seedA | `CmdHubCMD_keccak,      `CmdHubCMD_outer)

  always @(*) begin
    `SET_CMD__NONE
    if(oCurr == `MainSeqCMD_genA_iter) begin
      //--// _A = GEN(seedA)  -- only one row:  _A[o__genA__counter] <- SHAKE128(o__genA__counter | seedA)
      if(state[ 0]) `SET_CMD__KI_BYTE(o__genA__counter[0+:8])
      if(state[ 1]) `SET_CMD__KI_BYTE(o__genA__counter[8+:8])
      if(state[ 2]) `SET_CMD__S2K(`SET_CMD__IS_LAST)
`ifndef OUTPUT_INTERNALS_FOR_TEST
      if(state[ 3]) `SET_CMD__GENA__KOUT(config_frodoParam[2] ? 9'd16 : config_frodoParam[1] ? 9'd12 : 9'd8)
`else
      if(state[ 3]) `SET_CMD__GENA__KOUT_DBG(config_frodoParam[2] ? 9'd16 : config_frodoParam[1] ? 9'd12 : 9'd8)
`endif
    end
    //////////////////////////////////////////////////
    if(oCurr == `MainSeqCMD_keygen_PRNG) begin
      //--// OUT(sk.s) : 256b | BRAM.seedSE : 512b | seedA : 128b [=z] <- SHAKE256(0 : 8b | BRAM.RNG_state)
      if(state[ 0]) `SET_CMD__KI_BYTE(8'h00)
      if(state[ 1]) `SET_CMD__M2K(`MemAndMulCMD_out_RNGState, `SET_CMD__IS_LAST)
      if(state[ 2]) `SET_CMD__K_SINGLE
      if(state[ 3]) `SET_CMD__K2O(config_lenSec, `SET_CMD__NOT_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[ 4]) `SET_CMD__K2M(`MemAndMulCMD_in_seedSE, `SET_CMD__NOT_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[ 5]) `SET_CMD__K2S(`SET_CMD__IS_LAST)

      //--// BRAM.RNG_state <- SHAKE256(1 : 8b | BRAM.RNG_state)
      if(state[ 6]) `SET_CMD__K_SINGLE
      if(state[ 7]) `SET_CMD__KI_BYTE(8'h01)
      if(state[ 8]) `SET_CMD__M2K(`MemAndMulCMD_out_RNGState, `SET_CMD__IS_LAST)        
      if(state[ 9]) `SET_CMD__K2M(`MemAndMulCMD_in_RNGState, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
    end
    if(oCurr == `MainSeqCMD_keygen_noPRNG) begin
      //--// OUT(sk.s) : 256b <- BRAM.u [=s]
      if(state[ 0]) `SET_CMD__M2O(`MemAndMulCMD_out_u, `SET_CMD__NOT_PACKED)
    end
    if(oCurr == `MainSeqCMD_keygen_mid) begin
      //--// _r <- SHAKE256(0x5F | BRAM.seedSE)
      //--// BRAM.S' [=S^T] <- SampleMatrix(_r)
      //--// OUT(S^T) <- BRAM.S' [=S^T]
      //--// BRAM.B' [=E^T] <- ( SampleMatrix(_r) [=E] )^T
      if(state[ 0]) `SET_CMD__K_LONGOUT(config_frodoParam[2] ? 9'd317 : config_frodoParam[1] ? 9'd230 : 9'd122)
      if(state[ 1]) `SET_CMD__KI_BYTE(8'h5F)
      if(state[ 2]) `SET_CMD__M2K(`MemAndMulCMD_out_seedSE, `SET_CMD__IS_LAST)
      if(state[ 3]) `SET_CMD__K2MO(`MemAndMulCMD_in_SRowFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__NOT_LAST)
`ifndef OUTPUT_INTERNALS_FOR_TEST
      if(state[ 4]) `SET_CMD__K2M(`MemAndMulCMD_in_BColFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__IS_LAST)
`else
      if(state[ 4]) `SET_CMD__K2MO(`MemAndMulCMD_in_BColFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__IS_LAST)
`endif
      
      //--// seedA <- SHAKE256(seedA [=z])
      //--// OUT(seedA) <- seedA
      if(state[ 5]) `SET_CMD__K_SINGLE
      if(state[ 6]) `SET_CMD__S2K(`SET_CMD__IS_LAST)
      if(state[ 7]) `SET_CMD__K2SO(`SET_CMD__IS_LAST)
      if(state[ 8]) `SET_CMD__K_NO_OVERLAP
      
      //--// BRAM.B' [=B^T] = BRAM.B' [=E^T] + BRAM.S' [=S^T] *' _A^T
      if(state[ 9]) `SET_CMD__M(`MemAndMulCMD_inOp_BpleqStimesInAT)
    end
    if(oCurr == `MainSeqCMD_keygen_postGenA) begin
`ifndef OUTPUT_INTERNALS_FOR_TEST
      //--// _b <- pack( (BRAM.B' [=B^T])^T [=B] )
      //--// OUT(b) <- _b
      //--// OUT(pkh) : 256b <- SHAKE256(seedA | _b)
      if(state[ 0]) `SET_CMD__K_NO_OVERLAP
      if(state[ 1]) `SET_CMD__K_LONGIN(config_frodoParam[2] ? 9'd159 : config_frodoParam[1] ? 9'd115 : 9'd58)
      if(state[ 2]) `SET_CMD__S2K(`SET_CMD__NOT_LAST)
      if(state[ 3]) `SET_CMD__M2KO(`MemAndMulCMD_out_BColFirst, `SET_CMD__IS_PACKED, `SET_CMD__IS_LAST)
      if(state[ 4]) `SET_CMD__K2O(config_lenSec, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
      
      //--// BRAM.S' = 0
      if(state[ 5]) `SET_CMD__M(`MemAndMulCMD_op_Erase1)
`else
      if(state[ 0]) `SET_CMD__M2O(`MemAndMulCMD_out_BColFirst, `SET_CMD__NOT_PACKED)

      //--// _b <- pack( (BRAM.B' [=B^T])^T [=B] )
      //--// OUT(b) <- _b
      //--// OUT(pkh) : 256b <- SHAKE256(seedA | _b)
      if(state[ 1]) `SET_CMD__K_NO_OVERLAP
      if(state[ 2]) `SET_CMD__K_LONGIN(config_frodoParam[2] ? 9'd159 : config_frodoParam[1] ? 9'd115 : 9'd58)
      if(state[ 3]) `SET_CMD__S2K(`SET_CMD__NOT_LAST)
      if(state[ 4]) `SET_CMD__M2KO(`MemAndMulCMD_out_BColFirst, `SET_CMD__IS_PACKED, `SET_CMD__IS_LAST)
      if(state[ 5]) `SET_CMD__K2O(config_lenSec, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
      
      //--// BRAM.S' = 0
      if(state[ 6]) `SET_CMD__M(`MemAndMulCMD_op_Erase1)
`endif
    end
    //////////////////////////////////////////////////
    if(oCurr == `MainSeqCMD_encaps_prePRNG) begin
      //--// seedA : 128b <- IN(seedA)
      //--// _b <- IN(pk.b)
      //--// BRAM.B' [=B^T] = unpack(_b)^T
      //--// BRAM.pkh = SHAKE256(seedA|_b)
      if(state[ 0]) `SET_CMD__K_LONGIN(config_frodoParam[2] ? 9'd159 : config_frodoParam[1] ? 9'd115 : 9'd58)
      if(state[ 1]) `SET_CMD__O2SK(`SET_CMD__NOT_LAST)
      if(state[ 2]) `SET_CMD__O2MK(`MemAndMulCMD_in_BColFirst, `SET_CMD__IS_PACKED, `SET_CMD__IS_LAST)
      if(state[ 3]) `SET_CMD__K2M(`MemAndMulCMD_in_pkh, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
    end
    if(oCurr == `MainSeqCMD_encaps_PRNG) begin
      //--// BRAM.u | BRAM.salt <- SHAKE256(2 : 8b | BRAM.RNG_state)
      if(state[ 0]) `SET_CMD__K_SINGLE
      if(state[ 1]) `SET_CMD__KI_BYTE(8'h02)
      if(state[ 2]) `SET_CMD__M2K(`MemAndMulCMD_out_RNGState, `SET_CMD__IS_LAST)
      if(state[ 3]) `SET_CMD__K2M(`MemAndMulCMD_in_u, `SET_CMD__NOT_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[ 4]) `SET_CMD__K2M(`MemAndMulCMD_in_salt, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)

      //--// BRAM.RNG_state <- SHAKE256(3 : 8b | BRAM.RNG_state | BRAM.pkh)
      if(state[ 5]) `SET_CMD__K_SINGLE
      if(state[ 6]) `SET_CMD__KI_BYTE(8'h03)
      if(state[ 7]) `SET_CMD__M2K(`MemAndMulCMD_out_RNGState, `SET_CMD__NOT_LAST)
      if(state[ 8]) `SET_CMD__M2K(`MemAndMulCMD_out_pkh, `SET_CMD__IS_LAST)
      if(state[ 9]) `SET_CMD__K2M(`MemAndMulCMD_in_RNGState, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
    end
    if(oCurr == `MainSeqCMD_encaps_mid) begin
      if(state[ 0]) `SET_CMD__K_NO_OVERLAP
      //--// BRAM.seedSE | BRAM.k = SHAKE256(BRAM.pkh | BRAM.u | BRAM.salt) // end of pkh
      if(state[ 1]) `SET_CMD__K_SINGLE
      if(state[ 2]) `SET_CMD__M2K(`MemAndMulCMD_out_pkh, `SET_CMD__NOT_LAST)
      if(state[ 3]) `SET_CMD__M2K(`MemAndMulCMD_out_u, `SET_CMD__NOT_LAST)
      if(state[ 4]) `SET_CMD__M2K(`MemAndMulCMD_out_salt, `SET_CMD__IS_LAST)
      if(state[ 5]) `SET_CMD__K2M(`MemAndMulCMD_in_seedSE, `SET_CMD__NOT_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[ 6]) `SET_CMD__K2M(`MemAndMulCMD_in_k, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)

      //--// BRAM.C [=U] = Encode(BRAM.u) // end of u
      if(state[ 7]) `SET_CMD__M(`MemAndMulCMD_op_CeqU)
      if(state[ 8]) `SET_CMD__K_NO_OVERLAP
      
      //--// _r = SHAKE256(0x96 | seedSE) // end of seedSE
      //--// BRAM.S' [=S'] = SampleMatrix(_r)
      //--// BRAM.C [=C-E''] = BRAM.C [=U] + BRAM.S' *' BRAM.B'^T // end of B
      //--// BRAM.B' [=E'] = SampleMatrix(_r)
      //--// BRAM.C [=C] = BRAM.C + SampleMatrix(_r)
      if(state[ 9]) `SET_CMD__K_LONGOUT(config_frodoParam[2] ? 9'd318 : config_frodoParam[1] ? 9'd231 : 9'd123)
      if(state[10]) `SET_CMD__KI_BYTE(8'h96)
      if(state[11]) `SET_CMD__M2K(`MemAndMulCMD_out_seedSE, `SET_CMD__IS_LAST)
      if(state[12]) `SET_CMD__K2M(`MemAndMulCMD_in_SRowFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[13]) `SET_CMD__M(`MemAndMulCMD_op_CpleqStimesBT)
      if(state[14]) `SET_CMD__K2M(`MemAndMulCMD_in_BRowFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[15]) `SET_CMD__K2M(`MemAndMulCMD_inOp_addCRowFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__IS_LAST)

      //--// BRAM.B' [=B'] = BRAM.B' + BRAM.S' *" _A
      if(state[16]) `SET_CMD__M(`MemAndMulCMD_inOp_BpleqStimesInA)
    end
    if(oCurr == `MainSeqCMD_encaps_postGenA) begin
      if(state[ 0]) `SET_CMD__K_NO_OVERLAP
      //--// _c1 <- pack(BRAM.B')
      //--// _c2 <- pack(BRAM.C)
      //--// OUT(c1) <- _c1
      //--// OUT(c2) <- _c2
      //--// OUT(salt) <- BRAM.salt
      //--// OUT(ss) : 256b <- SHAKE(_c1 | _c2 | BRAM.salt | BRAM.k)
      if(state[ 1]) `SET_CMD__K_LONGIN(config_frodoParam[2] ? 9'd160 : config_frodoParam[1] ? 9'd117 : 9'd59)
      if(state[ 2]) `SET_CMD__M2KO(`MemAndMulCMD_out_BRowFirst, `SET_CMD__IS_PACKED, `SET_CMD__NOT_LAST)
      if(state[ 3]) `SET_CMD__M2KO(`MemAndMulCMD_out_CRowFirst, `SET_CMD__IS_PACKED, `SET_CMD__NOT_LAST)
      if(state[ 4]) `SET_CMD__M2KO(`MemAndMulCMD_out_salt, `SET_CMD__NOT_PACKED, `SET_CMD__NOT_LAST)
      if(state[ 5]) `SET_CMD__M2K(`MemAndMulCMD_out_k, `SET_CMD__IS_LAST)
      if(state[ 6]) `SET_CMD__K2O(config_lenSec, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)

      //--// BRAM.S' = 0
      if(state[ 7]) `SET_CMD__M(`MemAndMulCMD_op_Erase1)

      //--// BRAM.u = 0
      //--// BRAM.seedSE = 0
      //--// BRAM.k = 0
      if(state[ 8]) `SET_CMD__M(`MemAndMulCMD_op_Erase2)
    end
    //////////////////////////////////////////////////
    if(oCurr == `MainSeqCMD_decaps_preGenA) begin
      //--// BRAM.S' [=S^T] <- IN(sk.S^T)
      if(state[ 0]) `SET_CMD__O2M(`MemAndMulCMD_in_SRowFirst, `SET_CMD__NOT_PACKED)
      
      //--// _c1 <- IN(c.c1)
      //--// _c2 <- IN(c.c2)
      //--// BRAM.B' [=B'] <- unpack(_c1)
      //--// BRAM.C [=C] <- unpack(_c2)
      //--// BRAM.salt <- IN(c.salt)
      //--// BRAM.ss_state = SHAKE_partial(_c1 | _c2 | BRAM.salt)
      if(state[ 1]) `SET_CMD__K_OUTSTATE(config_frodoParam[2] ? 9'd160 : config_frodoParam[1] ? 9'd117 : 9'd59)
      if(state[ 2]) `SET_CMD__O2MK(`MemAndMulCMD_in_BRowFirst, `SET_CMD__IS_PACKED, `SET_CMD__NOT_LAST)
      if(state[ 3]) `SET_CMD__O2MK(`MemAndMulCMD_in_CRowFirst, `SET_CMD__IS_PACKED, `SET_CMD__NOT_LAST)
      if(state[ 4]) `SET_CMD__O2MK(`MemAndMulCMD_in_salt, `SET_CMD__NOT_PACKED, `SET_CMD__NOT_LAST)
      if(state[ 5]) `SET_CMD__KI_ZEROS(config_frodoParam[2] ? 8'd8 : config_frodoParam[1] ? 8'd15 : 8'd20)
`ifndef OUTPUT_INTERNALS_FOR_TEST
      if(state[ 6]) `SET_CMD__K2M(`MemAndMulCMD_in_SSState, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
`else
      if(state[ 6]) `SET_CMD__K2MO(`MemAndMulCMD_in_SSState, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
`endif
      
      //--// BRAM.u = decode(( BRAM.C^T - BRAM.S' *' BRAM.B'^T )^T)
      if(state[ 7]) `SET_CMD__M(`MemAndMulCMD_op_UeqCminBtimesS)
      
      //--// BRAM.pkh <- IN(sk.pkh)
      //--// BRAM.seedSE | BRAM.k = SHAKE256(BRAM.pkh | BRAM.u | BRAM.salt) // end pkh, salt
      if(state[ 8]) `SET_CMD__K_SINGLE
      if(state[ 9]) `SET_CMD__O2MK(`MemAndMulCMD_in_pkh, `SET_CMD__NOT_PACKED, `SET_CMD__NOT_LAST)
      if(state[10]) `SET_CMD__M2K(`MemAndMulCMD_out_u, `SET_CMD__NOT_LAST)
      if(state[11]) `SET_CMD__M2K(`MemAndMulCMD_out_salt, `SET_CMD__IS_LAST)

`ifndef OUTPUT_INTERNALS_FOR_TEST
      if(state[12]) `SET_CMD__K2M(`MemAndMulCMD_in_seedSE, `SET_CMD__NOT_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[13]) `SET_CMD__K2M(`MemAndMulCMD_in_k, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)

      //--// BRAM.C [=U-C] = Encode(BRAM.u) - BRAM.C // end of u
      if(state[14]) `SET_CMD__M(`MemAndMulCMD_op_CeqUminC)

      if(state[15]) `SET_CMD__K_NO_OVERLAP
      //--// _r = SHAKE256(0x96 | BRAM.seedSE) // end of seedSE
      //--// BRAM.S' = SampleMatrix(_r)
      //--// _B : 16b x 1344 x 8 <- unpack(IN(sk.b))
      //--// BRAM.C [=U-C+V-E''=C'-C-E''] = BRAM.C [=U-C] + BRAM.S' *' _B
      //--//   BRAM.B' [=E'-B'] = SampleMatrix(_r) [=E] - BRAM.B'
      //--// BRAM.C [=C'-C] = BRAM.C [=C'-C-E''] + SampleMatrix(_r) [=E'']
      if(state[16]) `SET_CMD__K_LONGOUT(config_frodoParam[2] ? 9'd318 : config_frodoParam[1] ? 9'd231 : 9'd123)
      if(state[17]) `SET_CMD__KI_BYTE(8'h96)
      if(state[18]) `SET_CMD__M2K(`MemAndMulCMD_out_seedSE, `SET_CMD__IS_LAST)
      if(state[19]) `SET_CMD__K2M(`MemAndMulCMD_in_SRowFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[20]) `SET_CMD__O2M(`MemAndMulCMD_inOp_CpleqStimesInBT, `SET_CMD__IS_PACKED)
      if(state[21]) `SET_CMD__K2M(`MemAndMulCMD_inOp_BeqInMinB, `SET_CMD__IS_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[22]) `SET_CMD__K2M(`MemAndMulCMD_inOp_addCRowFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__IS_LAST)

      //--// seedA : 128b <- IN(sk.seedA)
      if(state[23]) `SET_CMD__O2S

      if(state[24]) `SET_CMD__K_NO_OVERLAP
      //--// BRAM.B' = BRAM.B' [=B''-B'] + BRAM.S' *" _A
      if(state[25]) `SET_CMD__M(`MemAndMulCMD_inOp_BpleqStimesInA)
`else
      if(state[12]) `SET_CMD__K2MO(`MemAndMulCMD_in_seedSE, `SET_CMD__NOT_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[13]) `SET_CMD__K2MO(`MemAndMulCMD_in_k, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)

      //--// BRAM.C [=U-C] = Encode(BRAM.u) - BRAM.C // end of u
      if(state[14]) `SET_CMD__M(`MemAndMulCMD_op_CeqUminC)

      if(state[15]) `SET_CMD__K_NO_OVERLAP
      //--// _r = SHAKE256(0x96 | BRAM.seedSE) // end of seedSE
      //--// BRAM.S' = SampleMatrix(_r)
      //--// _B : 16b x 1344 x 8 <- unpack(IN(sk.b))
      //--// BRAM.C [=U-C+(V-E'')=C'-C-E'' ~-E''] = BRAM.C [=U-C] + BRAM.S' *' _B
      //--//   BRAM.B' [=E'-B'] = SampleMatrix(_r) [=E] - BRAM.B'
      //--// BRAM.C [=C'-C ~0] = BRAM.C [=C'-C-E'' ~-E''] + SampleMatrix(_r) [=E'']
      if(state[16]) `SET_CMD__K_LONGOUT(config_frodoParam[2] ? 9'd318 : config_frodoParam[1] ? 9'd231 : 9'd123)
      if(state[17]) `SET_CMD__KI_BYTE(8'h96)
      if(state[18]) `SET_CMD__M2K(`MemAndMulCMD_out_seedSE, `SET_CMD__IS_LAST)
      if(state[19]) `SET_CMD__K2MO(`MemAndMulCMD_in_SRowFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__NOT_LAST)
      if(state[20]) `SET_CMD__M2O(`MemAndMulCMD_out_CRowFirst, `SET_CMD__NOT_PACKED) // U-C  ~-V
      if(state[21]) `SET_CMD__O2M(`MemAndMulCMD_inOp_CpleqStimesInBT, `SET_CMD__IS_PACKED)
      if(state[22]) `SET_CMD__M2O(`MemAndMulCMD_out_CRowFirst, `SET_CMD__NOT_PACKED) // ~-E''
      if(state[23]) `SET_CMD__K2MO(`MemAndMulCMD_inOp_BeqInMinB, `SET_CMD__IS_SAMPLED, `SET_CMD__NOT_LAST) // out E'
      if(state[24]) `SET_CMD__K2MO(`MemAndMulCMD_inOp_addCRowFirst, `SET_CMD__IS_SAMPLED, `SET_CMD__IS_LAST) // out E''
      if(state[25]) `SET_CMD__M2O(`MemAndMulCMD_out_CRowFirst, `SET_CMD__IS_PACKED) // C'-C ~0

      //--// seedA : 128b <- IN(sk.seedA)
      if(state[26]) `SET_CMD__O2S

      if(state[27]) `SET_CMD__K_NO_OVERLAP
      //--// BRAM.B' = BRAM.B' [=B''-B'] + BRAM.S' *" _A
      if(state[28]) `SET_CMD__M(`MemAndMulCMD_inOp_BpleqStimesInA)
`endif
      
    end
   if(oCurr == `MainSeqCMD_decaps_mid) begin
`ifndef OUTPUT_INTERNALS_FOR_TEST
      //--// _corr = BRAM.B' == 0 && BRAM.C == 0
      //--// _s : 256b <- IN(sk.s)
      //--// BRAM.k = _corr ? BRAM.k : _s
      if(state[ 0]) `SET_CMD__O2M(`MemAndMulCMD_inOp_selectKey, `SET_CMD__NOT_PACKED)
      
      if(state[ 1]) `SET_CMD__K_NO_OVERLAP
      //--// BRAM.k [=ss] <- SHAKE_finish(ss_state, BRAM.k)
      //--// OUT(ss) <- BRAM.k
      if(state[ 2]) `SET_CMD__K_INSTATE(9'd1)
      if(state[ 3]) `SET_CMD__M2K(`MemAndMulCMD_out_SSState, `SET_CMD__NOT_LAST)
      if(state[ 4]) `SET_CMD__KI_ZEROS(config_frodoParam[2] ? 8'd9 : config_frodoParam[1] ? 8'd2 : 8'd1)
      if(state[ 5]) `SET_CMD__M2K(`MemAndMulCMD_out_k, `SET_CMD__IS_LAST)
      if(state[ 6]) `SET_CMD__K2MO(`MemAndMulCMD_in_k, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)  // ss
`else
      if(state[ 0]) `SET_CMD__M2O(`MemAndMulCMD_out_BRowFirst, `SET_CMD__IS_PACKED)
      if(state[ 1]) `SET_CMD__M2O(`MemAndMulCMD_out_CRowFirst, `SET_CMD__IS_PACKED)

      //--// _corr = BRAM.B' == 0 && BRAM.C == 0
      //--// _s : 256b <- IN(sk.s)
      //--// BRAM.k [=k'] = _corr ? BRAM.k : _s
      if(state[ 2]) `SET_CMD__O2M(`MemAndMulCMD_inOp_selectKey, `SET_CMD__NOT_PACKED)
      
      if(state[ 3]) `SET_CMD__K_NO_OVERLAP
      //--// BRAM.k [=ss] <- SHAKE_finish(ss_state, BRAM.k [=k'])
      //--// OUT(ss) <- BRAM.k
      if(state[ 4]) `SET_CMD__K_INSTATE(9'd1)
      if(state[ 5]) `SET_CMD__M2K(`MemAndMulCMD_out_SSState, `SET_CMD__NOT_LAST)
      if(state[ 6]) `SET_CMD__KI_ZEROS(config_frodoParam[2] ? 8'd9 : config_frodoParam[1] ? 8'd2 : 8'd1)
      if(state[ 7]) `SET_CMD__M2KO(`MemAndMulCMD_out_k, `SET_CMD__NOT_PACKED, `SET_CMD__IS_LAST) // k'
      if(state[ 8]) `SET_CMD__K2MO(`MemAndMulCMD_in_k, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST) // ss
`endif
    end
    if(oCurr == `MainSeqCMD_decaps_PRNG) begin
      //--// BRAM.RNG_state <- SHAKE256(4 : 8b | BRAM.RNG_state | BRAM.k [=ss])
      if(state[ 0]) `SET_CMD__K_SINGLE
      if(state[ 1]) `SET_CMD__KI_BYTE(8'h03)
      if(state[ 2]) `SET_CMD__M2K(`MemAndMulCMD_out_RNGState, `SET_CMD__NOT_LAST)
      if(state[ 3]) `SET_CMD__M2K(`MemAndMulCMD_out_k, `SET_CMD__IS_LAST)
      if(state[ 4]) `SET_CMD__K2M(`MemAndMulCMD_in_RNGState, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
    end
    if(oCurr == `MainSeqCMD_decaps_postPRNG) begin
      //--// BRAM.S' = 0
      if(state[ 0]) `SET_CMD__M(`MemAndMulCMD_op_Erase1)

      //--// BRAM.u = 0
      //--// BRAM.seedSE = 0
      //--// BRAM.k = 0
      if(state[ 1]) `SET_CMD__M(`MemAndMulCMD_op_Erase2)

      //--// BRAM.B' = 0
      //--// BRAM.C = 0
      if(state[ 2]) `SET_CMD__M(`MemAndMulCMD_op_Erase3)
    end
    //////////////////////////////////////////////////
    if(oCurr == `MainSeqCMD_setupTest) begin
      //--// BRAM.seedSE | BRAM.u | BRAM.salt | seedA <- IN
      if(state[ 0]) `SET_CMD__O2M(`MemAndMulCMD_in_seedSE, `SET_CMD__NOT_PACKED)
      if(state[ 1]) `SET_CMD__O2M(`MemAndMulCMD_in_u, `SET_CMD__NOT_PACKED)
      if(state[ 2]) `SET_CMD__O2M(`MemAndMulCMD_in_salt, `SET_CMD__NOT_PACKED)
      if(state[ 3]) `SET_CMD__O2S
    end
    //////////////////////////////////////////////////
    if(oCurr == `MainSeqCMD_addEntropy) begin
      //--// BRAM.RNG_state <- SHAKE256(5 : 8b | BRAM.RNG_state | IN : 512b)
      if(state[ 0]) `SET_CMD__K_SINGLE
      if(state[ 1]) `SET_CMD__KI_BYTE(8'h05)
      if(state[ 2]) `SET_CMD__M2K(`MemAndMulCMD_out_RNGState, `SET_CMD__NOT_LAST)
      if(state[ 3]) `SET_CMD__O2K(9'd16, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
      if(state[ 4]) `SET_CMD__K2M(`MemAndMulCMD_in_RNGState, `SET_CMD__NOT_SAMPLED, `SET_CMD__IS_LAST)
    end
  end
endmodule


`define MainFltCMD_genA              0
`define MainFltCMD_keygen_PRNG       1
`define MainFltCMD_keygen_mid        2
`define MainFltCMD_keygen_postGenA   3
`define MainFltCMD_encaps_prePRNG    4
`define MainFltCMD_encaps_PRNG       5
`define MainFltCMD_encaps_mid        6
`define MainFltCMD_encaps_postGenA   7
`define MainFltCMD_decaps_preGenA    8
`define MainFltCMD_decaps_mid        9
`define MainFltCMD_decaps_PRNG       10
`define MainFltCMD_decaps_postPRNG   11
`define MainFltCMD_setupTest         12
`define MainFltCMD_addEntropy        13

`define MainFltCMD_SIZE  4


// Inner Outer

module command_flattener(
    input [`MainFltCMD_SIZE-1:0] o_cmd,
    input o_isTest,
    input o_hasAny,
    output o_consume,

    output [`MainSeqCMD_SIZE-1:0] i,
    output i_isReady,
    input i_canReceive,
    output [16-1:0] i__genA__counter,

    input [16-1:0] config_matrixASizeMin1,
    
    input rst,
    input clk
  );
  wire genA__counter__canConsume;
  assign o_consume = o_hasAny & i_canReceive & ((o_cmd != `MainFltCMD_genA) | genA__counter__canConsume);

  assign i = (o_cmd == `MainFltCMD_genA             ? `MainSeqCMD_genA_iter : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_keygen_PRNG      ? (o_isTest ? `MainSeqCMD_keygen_noPRNG : `MainSeqCMD_keygen_PRNG) : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_keygen_mid       ? `MainSeqCMD_keygen_mid : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_keygen_postGenA  ? `MainSeqCMD_keygen_postGenA : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_encaps_prePRNG   ? `MainSeqCMD_encaps_prePRNG : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_encaps_PRNG      ? `MainSeqCMD_encaps_PRNG : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_encaps_mid       ? `MainSeqCMD_encaps_mid : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_encaps_postGenA  ? `MainSeqCMD_encaps_postGenA : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_decaps_preGenA   ? `MainSeqCMD_decaps_preGenA : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_decaps_mid       ? `MainSeqCMD_decaps_mid : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_decaps_PRNG      ? `MainSeqCMD_decaps_PRNG : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_decaps_postPRNG  ? `MainSeqCMD_decaps_postPRNG : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_setupTest        ? `MainSeqCMD_setupTest : {`MainSeqCMD_SIZE{1'b0}})
           | (o_cmd == `MainFltCMD_addEntropy       ? `MainSeqCMD_addEntropy : {`MainSeqCMD_SIZE{1'b0}});
  assign i_isReady = o_hasAny
                   & i_canReceive
                   & (o_cmd != `MainFltCMD_encaps_PRNG | ~o_isTest)
                   & (o_cmd != `MainFltCMD_decaps_PRNG | ~o_isTest);

  wire [16-1:0] genA__counter__d1;
  wire  [16-1:0] genA__counter = (o_cmd != `MainFltCMD_genA) || ~i_isReady   ? genA__counter__d1
                               : genA__counter__d1 == config_matrixASizeMin1 ? 16'd0
                                                                             : genA__counter__d1 + 16'b1;
  delay #(16) genA__counter__ff (genA__counter, genA__counter__d1, rst, clk);

  assign genA__counter__canConsume = genA__counter__d1 == config_matrixASizeMin1;
  ff_en_imm #(16) i__genA__counter__ff (i_isReady, genA__counter__d1, i__genA__counter, rst, clk);
endmodule



module command_main(
    input [`MainCMD_SIZE-1:0] o_cmd,
    input o_isReady, // must be false unless o_canReceive
    output o_canReceive, // the i/o could still be ongoing.

    output [`MainFltCMD_SIZE-1:0] i_cmd,
    output i_hasAny,
    input i_consume,

    input rst,
    input clk
  );
  wire [`MainCMD_SIZE-1:0] currCmd__d1;
  wire [`MainCMD_SIZE-1:0] currCmd = o_isReady ? o_cmd : currCmd__d1;
  delay #(`MainCMD_SIZE) currCmd__ff (currCmd, currCmd__d1, rst, clk);

  wire [3-1:0] state__numStates = (currCmd == `MainCMD_keygen ? 4 : 0)
                                | (currCmd == `MainCMD_encaps ? 5 : 0)
                                | (currCmd == `MainCMD_decaps ? 5 : 0)
                                | (currCmd == `MainCMD_setupTest ? 1 : 0)
                                | (currCmd == `MainCMD_addEntropy ? 1 : 0);
  wire [5-1:0] state;
  counter_bus_state #(.MAX_NUM_STEPS(5)) state__counter (
    .restart(o_isReady),
    .numStates(state__numStates),
    .canRestart(o_canReceive),
    
    .hasAny(i_hasAny),
    .state(state),
    .consume(i_consume),

    .rst(rst),
    .clk(clk)
  );
  
  reg [`MainFltCMD_SIZE-1:0] i_cmd__r;
  assign i_cmd = i_cmd__r;
  always @(*) begin
    i_cmd__r = {`MainSeqCMD_SIZE{1'b0}};
    if(currCmd == `MainCMD_keygen) begin
      if(state[0]) i_cmd__r = `MainFltCMD_keygen_PRNG;
      if(state[1]) i_cmd__r = `MainFltCMD_keygen_mid;
      if(state[2]) i_cmd__r = `MainFltCMD_genA;
      if(state[3]) i_cmd__r = `MainFltCMD_keygen_postGenA;
    end
    if(currCmd == `MainCMD_encaps) begin
      if(state[0]) i_cmd__r = `MainFltCMD_encaps_prePRNG;
      if(state[1]) i_cmd__r = `MainFltCMD_encaps_PRNG;
      if(state[2]) i_cmd__r = `MainFltCMD_encaps_mid;
      if(state[3]) i_cmd__r = `MainFltCMD_genA;
      if(state[4]) i_cmd__r = `MainFltCMD_encaps_postGenA;
    end
    if(currCmd == `MainCMD_decaps) begin
      if(state[0]) i_cmd__r = `MainFltCMD_decaps_preGenA;
      if(state[1]) i_cmd__r = `MainFltCMD_genA;
      if(state[2]) i_cmd__r = `MainFltCMD_decaps_mid;
      if(state[3]) i_cmd__r = `MainFltCMD_decaps_PRNG;
      if(state[4]) i_cmd__r = `MainFltCMD_decaps_postPRNG;
    end
    if(currCmd == `MainCMD_setupTest) begin
      if(state[0]) i_cmd__r = `MainFltCMD_setupTest;
    end
    if(currCmd == `MainCMD_addEntropy) begin
      if(state[0]) i_cmd__r = `MainFltCMD_addEntropy;
    end
  end
endmodule


// TODO: do not change the parameter set while the computation is ongoing

module main(
    input [`MainCMD_SIZE-1:0] cmd,
    input cmd_isReady, // must be false unless cmd_canReceive
    output cmd_canReceive, // the i/o could still be ongoing.

    input [64-1:0] in,
    input in_isReady,
    output in_canReceive,
    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,

    input rst, // needs a 1 clock delay.
    input clk
  );
  delay rst__ff(rst, rst__d1, 1'b0, clk);

  wire [`MainCMD_SIZE-1:0] cmdB;
  wire cmdB_isReady;
  wire cmdB_canReceive;
  bus_delay_std #(.BusSize(`MainCMD_SIZE), .N(1)) cmdDelay (
    .i(cmd),
    .i_isReady(cmd_isReady),
    .i_canReceive(cmd_canReceive),
    .o(cmdB),
    .o_isReady(cmdB_isReady),
    .o_canReceive(cmdB_canReceive),
    .rst(rst__d1),
    .clk(clk)
  );
  
  wire [64-1:0] outB;
  wire outB_isReady;
  wire outB_canReceive;
  bus_delay_std #(.BusSize(64), .N(1)) outDelay (
    .i(outB),
    .i_isReady(outB_isReady),
    .i_canReceive(outB_canReceive),
    .o(out),
    .o_isReady(out_isReady),
    .o_canReceive(out_canReceive),
    .rst(rst__d1),
    .clk(clk)
  );

  wire [3-1:0] frodoParam__set = {cmdB == `MainCMD_setParam1344, cmdB == `MainCMD_setParam976, cmdB == `MainCMD_setParam640};
  wire frodoParam__en = cmdB_isReady & ( | frodoParam__set );
  wire [3-1:0] frodoParam;
  ff_en_imm #(3) frodoParam__ff(frodoParam__en, frodoParam__set, frodoParam, rst, clk);


  wire [`MainCMD_SIZE-1:0] cmdC = cmdB;
  wire cmdC_isReady = cmdB_isReady & ~frodoParam__en;
  wire cmdC_canReceive;
  assign cmdB_canReceive = cmdC_canReceive;



  wire currCmd_isTest__set = cmdC == `MainCMD_setupTest;
  wire currCmd_isTest__d1;
  ff_sr_next currCmd_isTest__ff(currCmd_isTest__set, cmdC_isReady, currCmd_isTest__d1, rst__d1, clk);
  wire lastCmd_wasTest;
  ff_en_imm lastCmd_isTest__ff(cmdC_isReady, currCmd_isTest__d1, lastCmd_wasTest, rst__d1, clk);



  wire [`MainFltCMD_SIZE-1:0] cmdmDelay_cmd;
  wire cmdmDelay_hasAny;
  wire cmdmDelay_consume;
  command_main cmdm(
    .o_cmd(cmdC),
    .o_isReady(cmdC_isReady),
    .o_canReceive(cmdC_canReceive),
    .i_cmd(cmdmDelay_cmd),
    .i_hasAny(cmdmDelay_hasAny),
    .i_consume(cmdmDelay_consume),
    .rst(rst__d1),
    .clk(clk)
  );

  wire [`MainFltCMD_SIZE-1:0] flt_cmd;
  wire flt_hasAny;
  wire flt_consume;
  bus_delay_unstd #(.BusSize(`MainFltCMD_SIZE), .N(0)) cmdmDelay (
    .i(cmdmDelay_cmd),
    .i_hasAny(cmdmDelay_hasAny),
    .i_consume(cmdmDelay_consume),
    .o(flt_cmd),
    .o_hasAny(flt_hasAny),
    .o_consume(flt_consume),
    .rst(rst__d1),
    .clk(clk)
  );

  wire [`MainSeqCMD_SIZE-1:0] seq_cmd;
  wire seq_isReady;
  wire seq_canReceive;
  wire [16-1:0] seq_genA__counter;
  wire [16-1:0] config_matrixASizeMin1 = frodoParam[0] ? 16'd639
                                       : frodoParam[1] ? 16'd975
                                                       : 16'd1343;
  command_flattener flt(
    .o_cmd(flt_cmd),
    .o_isTest(lastCmd_wasTest),
    .o_hasAny(flt_hasAny),
    .o_consume(flt_consume),
    .i(seq_cmd),
    .i_isReady(seq_isReady),
    .i_canReceive(seq_canReceive),
    .i__genA__counter(seq_genA__counter),
    .config_matrixASizeMin1(config_matrixASizeMin1),
    .rst(rst__d1),
    .clk(clk)
  );

  wire [`MainExpCMD_SIZE-1:0] exp_cmd;
  wire exp__k_isLast;
  wire exp__k_isSampled;
  wire [9-1:0] exp__param;
  wire [6-1:0] exp__m_cmd;
  wire exp__m_isPack;
  wire [4-1:0] exp__h_dst;
  wire [4-1:0] exp__h_src;
  wire exp_hasAny;
  wire exp_consume;  
  command_sequences seq(
    .o(seq_cmd),
    .o_isReady(seq_isReady),
    .o_canReceive(seq_canReceive),
    .o__genA__counter(seq_genA__counter),
    .i(exp_cmd),
    .i__k_isLast(exp__k_isLast),
    .i__k_isSampled(exp__k_isSampled),
    .i__param(exp__param),
    .i__m_cmd(exp__m_cmd),
    .i__m_isPack(exp__m_isPack),
    .i__h_dst(exp__h_dst),
    .i__h_src(exp__h_src),
    .i_hasAny(exp_hasAny),
    .i_consume(exp_consume),
    .config_frodoParam(frodoParam),
    .rst(rst__d1),
    .clk(clk)
  );
  
  wire [`MainExpCMD_SIZE-1:0] expB_cmd;
  wire expB__k_isLast;
  wire expB__k_isSampled;
  wire [9-1:0] expB__param;
  wire [6-1:0] expB__m_cmd;
  wire expB__m_isPack;
  wire [4-1:0] expB__h_dst;
  wire [4-1:0] expB__h_src;
  wire expB_hasAny;
  wire expB_consume;  
  bus_delay_unstd #(.BusSize(`MainExpCMD_SIZE+2+9+6+1+4+4), .N(1)) expDelay (
    .i({exp_cmd,  exp__k_isLast,  exp__k_isSampled,  exp__param,  exp__m_cmd,  exp__m_isPack,  exp__h_dst,  exp__h_src}),
    .i_hasAny(exp_hasAny),
    .i_consume(exp_consume),
    .o({expB_cmd, expB__k_isLast, expB__k_isSampled, expB__param, expB__m_cmd, expB__m_isPack, expB__h_dst, expB__h_src}),
    .o_hasAny(expB_hasAny),
    .o_consume(expB_consume),
    .rst(rst__d1),
    .clk(clk)
  );
  

  wire [`MainCoreCMD_SIZE-1:0] core__cmd;
  wire [`MainCoreCMD_which_SIZE-1:0] core__cmd_hasAny;
  wire core__cmd_consume;
  command_expansion exp(
    .o(expB_cmd),
    .o__k_isLast(expB__k_isLast),
    .o__k_isSampled(expB__k_isSampled),
    .o__param(expB__param),
    .o__m_cmd(expB__m_cmd),
    .o__m_isPack(expB__m_isPack),
    .o__h_dst(expB__h_dst),
    .o__h_src(expB__h_src),
    .o_hasAny(expB_hasAny),
    .o_consume(expB_consume),
    .i(core__cmd),
    .i_hasAny(core__cmd_hasAny),
    .i_consume(core__cmd_consume),
    .config_useShake128(frodoParam[0])
  );

  wire [8-1:0] frodo_n = frodoParam[0] ? 8'd80
                       : frodoParam[1] ? 8'd122
                                       : 8'd168;
  main_core core(
    .cmd(core__cmd),
    .cmd_hasAny(core__cmd_hasAny),
    .cmd_consume(core__cmd_consume),
    .in(in),
    .in_isReady(in_isReady),
    .in_canReceive(in_canReceive),
    .out(outB),
    .out_isReady(outB_isReady),
    .out_canReceive(outB_canReceive),
    .conf({ frodo_n, frodoParam, frodoParam, frodoParam, frodoParam }),
    .rst(rst__d1),
    .clk(clk)
  );
endmodule

