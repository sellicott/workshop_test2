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

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();
  // cocotb interface signals
  reg test_done = 0;
  reg clk_dummy = 0;
  // driven by cocotb to assert control of the testing
  reg cocotb_tb = 0; 

  // global testbench signals
  localparam CLK_PERIOD    = 100;
  localparam TIMEOUT       = 5000;

  // global signals
  reg clk = 0;
  reg rst_n = 0;
  reg ena = 1;

// extra signals for doing gate level simulations
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Wire up the inputs and outputs:
  wire [7:0] ui_in;
  wire [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // watchdog timer signals
  reg run_timeout_counter;
  reg [15:0] timeout_counter = 0;

  // helper signals
  wire [7:0] fib_number = uo_out[7:0];

  reg  [7:0] fib_n = 0;
  reg  stb  = 0;
  wire busy = uio_out[1];

  assign uio_in[0]   = stb;
  assign uio_in[7:2] = 6'h0;
  assign ui_in[7:0]  = fib_n[7:0];

  // Replace tt_um_example with your module name:
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


  initial begin : fib_test
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;

    // only use the verilog testbench if we aren't uing a cocotb testbench
    if (cocotb_tb) begin
      $display("Run Cocotb Testbench");
      // wait until cocotb is done with the testbench
      while(cocotb_tb) @(negedge cocotb_tb);
      $finish;
    end

    // reset the system
    init();

    $display("Run Verilog Testbench");

    // test the first 10 fibonacci sequence numbers
    test_n_fib(10, TIMEOUT);

    // finish test successfully for cocotb
    test_done = 1;

    // finish the simulation
    close();
  end

  task test_n_fib (
    input integer n,
    input integer timeout
  );
    begin : test_n_fib_block
      integer fib_idx;
      fib_idx = 0;


      for (fib_idx = 0; fib_idx < n && timeout_counter < timeout; fib_idx++) begin : fib_test_iter
        integer fib_calc;
        integer fib_hw;
        fib_hw   = 0;

        // reset our watchdog timer
        reset_timeout_counter();

        // calculate the current fibonacci sequence value
        fib_calc = calc_fib(fib_idx);
        run_fib_seq(fib_idx);
        fib_hw = fib_number[7:0];
        $display("Test n=%d", fib_idx);
        $display("hw_fib: %d, sw fib: %d", fib_hw, fib_calc);

        // exit if the values don't match
        `assert_cond(fib_hw, ==, fib_calc);
      end

      // make sure we didn't run out the watchdog timer
      `assert_timeout(timeout);
    end
  endtask

  // make a task to read the fibonachi value
  task run_fib_seq(input integer n);
    begin: run_fib_block
      integer i;
      // wait a clock cycle and set the strobe signal
      @(posedge clk);
      stb = 1'h1;
      fib_n[7:0] = n[7:0];
      // wait a clock cycle and clear the strobe signal
      @(posedge clk);
      stb = 1'h0;
      @(posedge clk);
      // wait until the busy signal is low, each time wait another clock cycle
      for (i = 0; busy; i=i+1) @(posedge clk);
    end
  endtask

  // iteratively calculate the nth fibonacci sequence number
  function integer calc_fib(input integer n);
    begin : calc_fib_block
      integer a;
      integer b;
      integer c;
      integer i;

      a = 0;
      b = 1;
      c = 0;

      if (n == 0) begin
        calc_fib = a;
      end else begin
        for (i = 1; i < n; i++) begin
          c = a + b;
          a = b;
          b = c;
        end
        calc_fib = b;
      end

    end
  endfunction

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
      rst_n = 1;
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


  // System Clock 
  localparam CLK_HALF_PERIOD = CLK_PERIOD / 2;
  always #(CLK_HALF_PERIOD) begin
    if (!cocotb_tb) begin
      clk <= ~clk;
    end
  end

  // Timeout Clock
  always @(posedge clk) begin
    if (!cocotb_tb) begin
      if (run_timeout_counter) timeout_counter <= timeout_counter + 1'd1;
      else timeout_counter <= 16'h0;
    end
  end

endmodule
