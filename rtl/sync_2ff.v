// sync_2ff.v
//
// Generic 2-flip-flop synchronizer.
//
// Purpose: safely bring a signal from one clock domain into another.
// The FIRST flop (stage1) is the one that is allowed to go metastable --
// its input can change at any time relative to `clk`, with no timing
// relationship guaranteed. The SECOND flop (d_out) samples stage1 one
// full clock period later, by which time stage1 has almost certainly
// resolved to a clean 0 or 1. That's the entire trick: buy the
// metastable value one extra cycle to settle before anything downstream
// depends on it.
//
// IMPORTANT LIMITATION (read this before trusting the testbench):
// Icarus Verilog is a digital logic simulator. It has no concept of an
// analog voltage sitting between 0 and 1 -- so this testbench can prove
// the LATENCY and DATA behavior are correct, but it cannot actually
// demonstrate metastability itself. Real metastability is a transistor-
// level phenomenon; proving a flop's MTBF against it requires SPICE-level
// analog simulation, which is a separate, specialized step done by the
// standard-cell library vendor, not something you verify in RTL sim.

`timescale 1ns/1ps

module sync_2ff #(
    parameter WIDTH = 4
) (
    input  wire             clk,     // destination domain clock
    input  wire             rst_n,   // active-low async reset, destination domain
    input  wire [WIDTH-1:0] d_in,    // signal arriving FROM the other clock domain
    output reg  [WIDTH-1:0] d_out    // synchronized signal, safe to use in this domain
);

    reg [WIDTH-1:0] stage1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= {WIDTH{1'b0}};
            d_out  <= {WIDTH{1'b0}};
        end else begin
            stage1 <= d_in;    // stage 1: may go metastable, that is expected and fine
            d_out  <= stage1;  // stage 2: samples stage1 one cycle later, once settled
        end
    end

endmodule
