`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();
  // cocotb interface signals
  reg test_done = 0;
  reg clk_dummy = 0;

  // global testbench signals
  localparam CLK_PERIOD = 100;

  // signals that we will access directly
  reg clk   = 0;
  reg rst_n = 0;
  reg ena   = 1;

  // Wire up the inputs and outputs:
  reg [7:0] ui_in  = 0;
  reg [7:0] uio_in = 0;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

// extra signals for doing gate level simulations
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // System Clock 
  localparam CLK_HALF_PERIOD = CLK_PERIOD / 2;
  always #(CLK_HALF_PERIOD) begin
    clk <= ~clk;
  end

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin: startup
    integer i;

    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
    $display("Simulation Start");
    $display("Reset");

    // wait for a bit then stop resetting the testbench
    repeat (2) @(posedge clk);
    rst_n = 1;
    $display("Run");

    // run for 5 cycles disabled
    for ( i = 0; i < 5; i = i + 1) begin 
      @(posedge clk);
      $display("counter value: %d", uo_out);
    end

    // enable the counter
    ui_in[0] = 1'h1;
    // run for 10 cycles enabled 
    for ( i = 0; i < 10; i = i + 1) begin 
      @(posedge clk);
      $display("counter value: %d", uo_out);
    end

    // disable the counter
    ui_in[0] = 1'h0;
    // run for 10 cycles disabled 
    for ( i = 0; i < 5; i = i + 1) begin 
      @(posedge clk);
      $display("counter value: %d", uo_out);
    end

    // enable the counter
    ui_in[0] = 1'h1;
    // test for overflow
    for ( i = 0; i < 256; i = i + 1) begin 
      @(posedge clk);
      $display("counter value: %d", uo_out);
    end

    test_done = 1;

    // close the output file
    $display("Closing");
    repeat (10) @(posedge clk);
    $finish;
  end

  // Replace tt_um_ieee_demo with your module name:
  tt_um_ieee_demo user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
