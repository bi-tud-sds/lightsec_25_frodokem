`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/08/2025 04:12:12 PM
// Design Name: 
// Module Name: seedAStorage
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

`include "lib.v"

`define SeedAStorageCMD_SIZE 1


module seedAStorage (
    input [`SeedAStorageCMD_SIZE-1:0] cmd, // { cmd_startInElseOut:1bit }
    input cmd_isReady,
    output cmd_canReceive,

    input [64-1:0] in,
    input in_isReady,
    output in_canReceive,
    output in_isLast,

    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,
    output out_isLast,

    input rst,
    input clk
  );
  wire [`SeedAStorageCMD_SIZE-1:0] cmdB;
  wire cmdB_isReady;
  wire cmdB_canReceive;
  bus_delay_std #(.BusSize(`SeedAStorageCMD_SIZE), .N(2)) cmdBuffer (
    .i(cmd),
    .i_isReady(cmd_isReady),
    .i_canReceive(cmd_canReceive),
    .o(cmdB),
    .o_isReady(cmdB_isReady),
    .o_canReceive(cmdB_canReceive),
    .rst(rst),
    .clk(clk)
  );
  wire cmdB_startIn = cmdB[0] & cmdB_isReady;
  wire cmdB_startOut = ~cmdB[0] & cmdB_isReady;

  wire isInElseOut;
  ff_en_imm isInElseOut__ff (cmdB_isReady, cmdB[0], isInElseOut, rst, clk);

  wire [128-1:0] storage__a1;
  wire [128-1:0] storage;
  delay #(128) storage__ff (storage__a1, storage, 1'b0, clk); // don't reset the storage, like for the brams. This is data, not control, so it will be overwritten when necessary. This is necessary to reset all the control stuff without resetting the info, e.g. in case we setup a test.

  wire des_isReady = in_isReady & isInElseOut;
  wire des_canReceive;
  assign in_canReceive = des_canReceive & isInElseOut;
  wire ser_canReceive = out_canReceive & ~isInElseOut;
  wire ser_isReady;
  assign out_isReady = ser_isReady & ~isInElseOut;
  serdes #(2) serdes (
    .cmd_startSer(cmdB_startOut),
    .cmd_startDes(cmdB_startIn),
    .cmd_canReceive(cmdB_canReceive),
    .buffer_write(storage__a1),
    .buffer_read(storage),
    .des(in),
    .des_isReady(des_isReady),
    .des_canReceive(des_canReceive),
    .des_isLast(in_isLast),
    .ser(out),
    .ser_isReady(ser_isReady),
    .ser_canReceive(ser_canReceive),
    .ser_isLast(out_isLast),
    .rst(rst),
    .clk(clk)
  );
endmodule



