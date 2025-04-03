
/* clk_gen_tb.v
 * Copyright (c) 2024 Samuel Ellicott
 * SPDX-License-Identifier: Apache-2.0
 *
 * Testbench for the strobe signal generation module
 */
`timescale 1ns / 1ns
`default_nettype none

// Assert helpers for ending the simulation early in failure
`define assert(signal, value) \
  if (signal !== value) begin \
    $display("ASSERTION FAILED in %m:\nEquality"); \
    $display("\t%d (expected) != %d (actual)", value, signal); \
    close(); \
  end

`define assert_cond(signal, cond, value) \
  if (!(signal cond value)) begin \
    $display("ASSERTION FAILED in %m:\nCondition:"); \
    $display("\n\texpected: %d\n\tactual: %d", value, signal); \
    close(); \
  end

`define assert_timeout(max_count) \
  if (!(timeout_counter < max_count)) begin \
    $display("ASSERTION FAILED in %m\nTimeout:"); \
    $display("\tspecified max count: %d\n\tactual count: %d", max_count, timeout_counter); \
    close(); \
  end

module clk_gen_tb ();
  // cocotb interface signals
  reg test_done = 0;

  // global testbench signals
  localparam CLK_PERIOD    = 100;
  localparam REFCLK_PERIOD = 1003;
  localparam TIMEOUT       = 100000;

  reg clk = 0;
  reg refclk = 0;
  reg reset_n = 0;
  reg ena = 1;

  reg run_timeout_counter;
  reg [15:0] timeout_counter = 0;

  // setup top level testbench signals
  wire gen_1hz_stb;
  wire slow_set_stb;
  wire fast_set_stb;
  wire debounce_stb;

  // setup file dumping things
  localparam STARTUP_DELAY = 5;
  initial begin
    $dumpfile("clk_gen_tb.fst");
    $dumpvars(0, clk_gen_tb);
    #STARTUP_DELAY;

    $display("Clock Strobe Generation Testbench");
    init();

    // TODO: Run all our tests here
    $display("Testing 1Hz Strobe Generation");
    test_1hz_stb(TIMEOUT);
    $display("Testing 1Hz Strobe Generation: PASS");

    $display("Testing Debounce Strobe Generation");
    test_debounce_stb(TIMEOUT);
    $display("Testing Debounce Strobe Generation: PASS");

    $display("Testing Fast Set Strobe Generation");
    test_fast_set_stb(TIMEOUT);
    $display("Testing Fast Set Strobe Generation: PASS");

    $display("Testing Slow Set Strobe Generation");
    test_slow_set_stb(TIMEOUT);
    $display("Testing Slow Set Strobe Generation: PASS");

    test_done = 1;
    // exit the simulator
    close();
  end

  // System Clock 
  localparam CLK_HALF_PERIOD = CLK_PERIOD / 2;
  always #(CLK_HALF_PERIOD) begin
    clk <= ~clk;
  end

  localparam REFCLK_HALF_PERIOD = REFCLK_PERIOD / 2;
  always #(REFCLK_HALF_PERIOD) begin
    refclk <= ~refclk;
  end

  // Timeout Clock
  always @(posedge clk) begin
    if (run_timeout_counter) timeout_counter <= timeout_counter + 1'd1;
    else timeout_counter <= 16'h0;
  end

  // setup power pins if doing post-synthesis simulations
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif


  // Add device to test here
  clk_gen clk_gen_inst (
    // global signals
    .i_reset_n(reset_n),
    .i_clk(clk),
    // Strobe from 32,768 Hz reference clock
    .i_refclk(refclk),
    // output strobe signals
    .o_1hz_stb(gen_1hz_stb),      // refclk / 2^15 -> 1Hz
    .o_slow_set_stb(slow_set_stb), // refclk / 2^14 -> 2Hz
    .o_fast_set_stb(fast_set_stb), // refclk / 2^12 -> 8Hz
    .o_debounce_stb(debounce_stb)  // refclk / 2^4  -> 4.096KHz
  );


  // Tasks for running simulations
  // I usually put these at the end so that I can access all the signals in
  // the testbench
  reg [1:0] refclk_rising = 0;
  wire refclk_stb = !refclk_rising[1] && refclk_rising[0];
  always @(posedge clk) begin
    refclk_rising <= {refclk_rising[0], refclk};
  end


  task test_1hz_stb(
    input integer timeout
  );
    begin : gen_1hz_stb_test
      integer refclk_count;

      // make sure we are getting a full count
      reset_timeout_counter();
      refclk_count = 0;
      while ( !gen_1hz_stb && timeout_counter < timeout) begin 
        @(posedge clk);
        if (refclk_stb) begin
          refclk_count = refclk_count + 1;
        end
      end
      `assert_timeout(timeout);
      `assert_cond(gen_1hz_stb, ==, 1'b1);
      // wait one more clock cycle
      @(posedge clk);
      `assert_cond(gen_1hz_stb, ==, 1'b0);

      reset_timeout_counter();
      refclk_count = 0;
      // wait until the 1hz_stb_signal is asserted
      while ( !gen_1hz_stb && timeout_counter < timeout) begin 
        @(posedge clk);
        if (refclk_stb) begin
          refclk_count = refclk_count + 1;
        end
      end

      // make sure we didn't run out the watchdog timer
      `assert_timeout(timeout);
      `assert_cond(gen_1hz_stb, ==, 1'b1);
      `assert_cond(refclk_count, ==, (1 << 15));

    end
  endtask

  task test_debounce_stb(
    input integer timeout
  );
    begin : debounce_stb_test
      integer refclk_count;

      // make sure we are getting a full count
      reset_timeout_counter();
      refclk_count = 0;
      while ( !debounce_stb && timeout_counter < timeout) begin 
        @(posedge clk);
        if (refclk_stb) begin
          refclk_count = refclk_count + 1;
        end
      end
      `assert_timeout(timeout);
      `assert_cond(debounce_stb, ==, 1'b1);
      // wait one more clock cycle
      @(posedge clk);
      `assert_cond(debounce_stb, ==, 1'b0);

      reset_timeout_counter();
      refclk_count = 0;
      // wait until the 1hz_stb_signal is asserted
      while ( !debounce_stb && timeout_counter < timeout) begin 
        @(posedge clk);
        if (refclk_stb) begin
          refclk_count = refclk_count + 1;
        end
      end

      // make sure we didn't run out the watchdog timer
      `assert_timeout(timeout);
      `assert_cond(debounce_stb, ==, 1'b1);
      `assert_cond(refclk_count, ==, (1 << 4));

    end
  endtask

  task test_fast_set_stb(
    input integer timeout
  );
    begin : fast_set_stb_test
      integer refclk_count;

      // make sure we are getting a full count
      reset_timeout_counter();
      refclk_count = 0;
      while ( !fast_set_stb && timeout_counter < timeout) begin 
        @(posedge clk);
        if (refclk_stb) begin
          refclk_count = refclk_count + 1;
        end
      end
      `assert_timeout(timeout);
      `assert_cond(fast_set_stb, ==, 1'b1);
      // wait one more clock cycle
      @(posedge clk);
      `assert_cond(fast_set_stb, ==, 1'b0);

      reset_timeout_counter();
      refclk_count = 0;
      // wait until the 1hz_stb_signal is asserted
      while ( !fast_set_stb && timeout_counter < timeout) begin 
        @(posedge clk);
        if (refclk_stb) begin
          refclk_count = refclk_count + 1;
        end
      end

      // make sure we didn't run out the watchdog timer
      `assert_timeout(timeout);
      `assert_cond(fast_set_stb, ==, 1'b1);
      `assert_cond(refclk_count, ==, (1 << 12));

    end
  endtask

  task test_slow_set_stb(
    input integer timeout
  );
    begin : slow_set_stb_test
      integer refclk_count;

      // make sure we are getting a full count
      reset_timeout_counter();
      refclk_count = 0;
      while ( !slow_set_stb && timeout_counter < timeout) begin 
        @(posedge clk);
        if (refclk_stb) begin
          refclk_count = refclk_count + 1;
        end
      end
      `assert_timeout(timeout);
      `assert_cond(slow_set_stb, ==, 1'b1);
      // wait one more clock cycle
      @(posedge clk);
      `assert_cond(slow_set_stb, ==, 1'b0);

      reset_timeout_counter();
      refclk_count = 0;
      // wait until the 1hz_stb_signal is asserted
      while ( !slow_set_stb && timeout_counter < timeout) begin 
        @(posedge clk);
        if (refclk_stb) begin
          refclk_count = refclk_count + 1;
        end
      end

      // make sure we didn't run out the watchdog timer
      `assert_timeout(timeout);
      `assert_cond(fast_set_stb, ==, 1'b1);
      `assert_cond(refclk_count, ==, (1 << 13));

    end
  endtask

  task reset_timeout_counter();
    begin
      @(posedge clk);
      run_timeout_counter = 1'd0;
      @(posedge clk);
      run_timeout_counter = 1'd1;
    end
  endtask

  task init();
    begin
      $display("Simulation Start");
      $display("Reset");

      repeat (2) @(posedge clk);
      reset_n = 1;
      $display("Run");
    end
  endtask

  task close();
    begin
      $display("Closing");
      repeat (10) @(posedge clk);
      $finish;
    end
  endtask

endmodule
