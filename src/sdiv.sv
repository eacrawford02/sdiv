// Copyright (C) 2023 Ewen Crawford
`timescale 1ns / 1ps

// Fully pipelined restoring array divider. Supports both signed and unsigned
// integer inputs
module sdiv #(
  parameter M = 32,         // Numerator bit width
  parameter N = 32          // Denominator bit width
) (
  input                clk,
  input                en,  // Start calculation with current inputs (n, d)
  input        [M-1:0] n,   // Numerator
  input        [N-1:0] d,   // Denominator
  output               vld, // Indicate whether current outputs (q, r) are valid
  output logic [M-1:0] q,   // Quotient
  output logic [N-1:0] r    // Remainder
);
  // Elaboration system task, validate parameter values
  if (N > M) // Conditional generate construct
    $warning("Numerator bit width (parameter M, %0d bits) ", M,
	     "must be grater than or equal to denominator bit width ",
	     "(parameter N, %0d bits)", N);

  logic [M-1:0] n_u; // Unsigned numerator
  logic [N-1:0] d_u; // Unsigned denominator
  logic [M:0] vld_dly, out_sign; // Shift registers to hold valid signal and 
				   // output sign signal associated with the 
				   // division operation in the corresponding 
				   // pipeline stage
  logic [N:0] fa_out [M-1:0]; // Holds partial remainder for each stage 
			      // (N LSBs) and carry-out (MSB)
  logic [M+N-2:0] regs [M:0]; // Registers to hold carry-out(s), FA sums, and 
			      // LSBs of numerator for each stage. Note that 
			      // last stage register holds 0 numerator LSBs

  assign vld = vld_dly[M];
  
  always_comb begin
    // Convert numerator and denominator to unsigned numbers
    n_u = n[M-1] ? ~n + 1 : n;
    d_u = d[N-1] ? ~d + 1 : d;
    // Recover quotient sign
    q = out_sign[M-1] ? ~regs[M][M+N-2:N-1] + 1 : regs[M][M+N-2:N-1];
  end

  always_ff @ (posedge clk) begin
    // Shift valid signal and output signal
    vld_dly <= {vld_dly[M-1:0], en};
    out_sign <= {out_sign[M-1:0], n[M-1] ^ d[N-1]};
    // Register first stage inputs
    regs[0] <= {{31{1'b0}}, n_u};
    // Register last stage output (final remainder) less the MSB (carry out)
    r <= fa_out[M-1][N-1:0];
  end

  genvar i, j;
  generate
    for (i = 1; i <= M; i++) begin : gen_stage_regs
      always_ff @ (posedge clk) begin
	if (i >= 2)
	  // Register previous carry bits
	  regs[i][M+N-2:M+N-i] <= regs[i-1][M+N-2:M+N-i];
	// Register current carry bit
	regs[i][M+N-1-i] <= fa_out[i-1][N];
	// Drop MSB of full adder (bit 31)
	regs[i][M+N-2-i:M-i] <= fa_out[i-1][N-1:0];
	if (i < M)
	  // Shift numerator in
	  regs[i][M-1-i:0] <= regs[i-1][M-1-i:0];
      end
    end
  endgenerate

  generate
    for (j = 0; j < M; j++) begin : gen_stage_logic
      rca_sel #(
	.WIDTH(N)
      ) stage_j(
	.a(regs[j][M+N-2-j:M-1-j]),
	.b(d_u),
	.cout(fa_out[j][N]),
	.r(fa_out[j][N-1:0])
      );
    end
  endgenerate
endmodule

// Ripple carry adder with automatic output selection function. Computes single 
// bit of quotient and the corresponding partial remainder. Inputs `a` and `b` 
// are both treated as unsigned integers
module rca_sel #(
  parameter WIDTH = 32
) (
  input  [WIDTH-1:0] a,
  input  [WIDTH-1:0] b,
  output             cout,
  output [WIDTH-1:0] r
);
  logic [WIDTH-1:0] si; // FA intermediate sum outputs to mux against final 
			// carry out
  logic [WIDTH:0] ci; // Intermediate carries
  assign ci[0] = 1'b1; // set carry in to 1 (always subtract)

  always_comb begin
    for (int i = 0; i < WIDTH; i++) begin
      // Ensure that `b` is complemented to always subtract `b` from `a`
      si[i] = a[i] ^ ~b[i] ^ ci[i];
      // Generate intermediate carry
      ci[i+1] = (a[i] & ~b[i]) | (ci[i] & (a[i] ^ ~b[i]));
    end
  end

  // Select between sum and input `a` based on final carry out
  assign r = ci[WIDTH] ? si : a;
  // Assign final carry out
  assign cout = ci[WIDTH];
endmodule
