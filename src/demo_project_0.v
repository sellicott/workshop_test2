/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_ieee_demo (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

// define wires for the counter module
wire       count_en  = ui_in[0];
wire [7:0] count_out;

// instantiate counter module
counter_8bit counter_inst (
    .i_reset_n(rst_n),
    .i_clk(clk),
    .i_en(count_en),
    .o_count(count_out)
);

// assign output wires
assign uo_out[7:0] = count_out;

// All output pins must be assigned. If not used, assign to 0.
assign uio_out = 0;
assign uio_oe  = 0;

// List all unused inputs to prevent warnings
wire _unused = &{ena, ui_in[7:1], uio_in, 1'b0};

endmodule

// very basic counter module
module counter_8bit (
    i_reset_n,
    i_clk,
    // only count when enabled
    i_en,
    // output
    o_count
);
// define global inputs
input wire i_reset_n;
input wire i_clk;

// define module inputs
input wire i_en;

// define module outputs
output wire [7:0] o_count;

// counter implementation
reg [7:0] count_reg;
always @(posedge i_clk) begin
    // reset counter if i_reset_n is low
    if (!i_reset_n) begin
        count_reg <= 8'h0;
    end
    // if the counter is enabled then count up
    else if (i_en) begin
        count_reg <= count_reg + 8'h1;
    end
end

// attach the counter register to the output wires
assign o_count[7:0] = count_reg[7:0];

endmodule
