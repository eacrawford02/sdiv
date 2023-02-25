// Copyright (C) 2023 Ewen Crawford
`timescale 1ns / 1ps

module tb ();
  // Generate 100 MHz clock
  logic clk = 0;
  always #5 clk <= ~clk;

  logic en = 0;
  logic [31:0] n = 32'hFFFFFFEE, d = 32'h00000005;
  logic vld;
  logic [31:0] q, r;

  sdiv dut2(
    .clk(clk),
    .en(en),
    .n(n),
    .d(d),
    .vld(vld),
    .q(q),
    .r(r)
  );

  initial begin
    $display("================ DIVIDER TEST ================");
    en = 1;
    @ (posedge vld); 
    $display("n = %b = %0d", n, $signed(n));
    $display("d = %b = %0d", d, d);
    $display("q = %b = %0d", q, $signed(q));
    $display("r = %b = %0d", r, r);
    for (int i = 0; i <= 32; i++) begin
      if (i > 0) $display("Partial remainder %0d = %b", i-1, dut2.fa_out[i-1]);
      $display("Register %0d contents = %b", i, dut2.regs[i]);
    end
    $finish;
  end
endmodule
