// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//############################################################################
// *Name: sys_osc
// *Module Description: System Clock Oscilator
//############################################################################

module sys_osc (
  input vcore_pok_h_i,    // VCORE POK @3.3V
  input sys_en_i,         // System Source Clock Enable
  input sys_jen_i,        // System Source Clock Jitter Enable
`ifdef AST_BYPASS_CLK
  input clk_sys_ext_i,    // FPGA/VERILATOR Clock input
`endif
  output logic sys_clk_o  // System Clock Output
);

`ifndef AST_BYPASS_CLK
`ifndef SYNTHESIS
// Behavioral Model
////////////////////////////////////////
timeunit  1ns / 1ps;
import ast_bhv_pkg::* ;

localparam real SysClkPeriod = 10000; // 10000ps (100Mhz)
logic clk;
shortreal jitter;

initial begin
  clk  = 1'b0;
  $display("\nSYS Clock Period: %0dps", SysClkPeriod);
end

// Enable 5us RC Delay on rise
logic en_osc_re;
buf #(SYS_EN_RDLY, 0) b0 (en_osc_re, (vcore_pok_h_i && sys_en_i));

// Clock Oscillator
////////////////////////////////////////
logic en_osc;

always begin
  // 0-2000ps is upto +20% Jitter
  jitter = sys_jen_i ? $urandom_range(2000, 0) : 0;
  #((SysClkPeriod+jitter)/2000) clk = ~clk && en_osc;
end
`else  // of SYBTHESIS
// SYNTHESIS/LINTER
///////////////////////////////////////
logic en_osc_re;
assign en_osc_re = vcore_pok_h_i && sys_en_i;

logic clk, en_osc;
assign clk = 1'b0;
`endif  // of SYBTHESIS
`else  // of AST_BYPASS_CLK
// VERILATOR/FPGA
///////////////////////////////////////
logic en_osc_re;
assign en_osc_re = vcore_pok_h_i && sys_en_i;

// Clock Oscillator
////////////////////////////////////////
logic clk, en_osc;

prim_clock_gating #(
  .NoFpgaGate ( 1'b1 )
) u_clk_ckgt (
  .clk_i ( clk_sys_ext_i ),
  .en_i ( en_osc ),
  .test_en_i ( 1'b0 ),
  .clk_o ( clk )
);
`endif

logic en_osc_fe;

// Syncronize en_osc to clk FE for glitch free disable
always_ff @( negedge clk, negedge vcore_pok_h_i ) begin
  if ( !vcore_pok_h_i ) begin
    en_osc_fe <= 1'b0;
  end else begin
    en_osc_fe <= en_osc_re;
  end
end

assign en_osc = en_osc_re || en_osc_fe;  // EN -> 1 || EN -> 0

// Clock Output Buffer
////////////////////////////////////////
prim_clock_buf #(
  .NoFpgaBuf ( 1'b1 )
) u_buf (
  .clk_i ( clk ),
  .clk_o ( sys_clk_o )
);


`ifdef SYNTHESIS
/////////////////////////
// Unused Signals
/////////////////////////
logic unused_sigs;
assign unused_sigs = ^{ sys_jen_i };      // Used in ASIC implementation
`endif

endmodule : sys_osc
