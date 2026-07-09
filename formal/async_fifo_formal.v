// async_fifo_formal.v
//
// Formal verification wrapper.
//
// Instead of instantiating the top-level async_fifo and trying to probe
// its internal signals hierarchically (which Yosys formal doesn't support
// reliably), we instantiate all sub-modules directly. Every pointer and
// flag is then a plain named wire -- no hierarchical dot-notation needed.
//
// Three properties are proven:
//   P1 - full and empty are never both asserted in steady state
//   P2 - when empty: read pointer gray == synchronized write pointer gray
//   P3 - when full:  write pointer gray matches the Cummings MSB-inversion
//                    of the synchronized read pointer gray

`default_nettype none
`timescale 1ns/1ps

module async_fifo_formal #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3
) (
    input wire                  wr_clk,
    input wire                  rd_clk,
    input wire                  wr_rst_n,
    input wire                  rd_rst_n,
    input wire                  wr_en,
    input wire                  rd_en,
    input wire [DATA_WIDTH-1:0] wr_data
);

    // ── wires connecting sub-modules ──────────────────────────────────
    wire [ADDR_WIDTH:0]   wr_ptr_gray;        // write-domain gray pointer (→ sync into read)
    wire [ADDR_WIDTH:0]   rd_ptr_gray;        // read-domain gray pointer  (→ sync into write)
    wire [ADDR_WIDTH:0]   wr_ptr_gray_rd;     // wr_ptr_gray synced into rd_clk domain
    wire [ADDR_WIDTH:0]   rd_ptr_gray_wr;     // rd_ptr_gray synced into wr_clk domain
    wire [ADDR_WIDTH-1:0] wr_addr;
    wire [ADDR_WIDTH-1:0] rd_addr;
    wire                  full;
    wire                  empty;
    wire [DATA_WIDTH-1:0] rd_data;

    // ── sub-module instantiation ──────────────────────────────────────
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_wr2rd (
        .clk   (rd_clk),
        .rst_n (rd_rst_n),
        .d_in  (wr_ptr_gray),
        .d_out (wr_ptr_gray_rd)
    );

    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_rd2wr (
        .clk   (wr_clk),
        .rst_n (wr_rst_n),
        .d_in  (rd_ptr_gray),
        .d_out (rd_ptr_gray_wr)
    );

    wptr_full #(.ADDR_WIDTH(ADDR_WIDTH)) u_wptr_full (
        .wr_clk           (wr_clk),
        .wr_rst_n         (wr_rst_n),
        .wr_en            (wr_en),
        .rd_ptr_gray_sync (rd_ptr_gray_wr),
        .wr_addr          (wr_addr),
        .wr_ptr_gray      (wr_ptr_gray),
        .full             (full)
    );

    rptr_empty #(.ADDR_WIDTH(ADDR_WIDTH)) u_rptr_empty (
        .rd_clk           (rd_clk),
        .rd_rst_n         (rd_rst_n),
        .rd_en            (rd_en),
        .wr_ptr_gray_sync (wr_ptr_gray_rd),
        .rd_addr          (rd_addr),
        .rd_ptr_gray      (rd_ptr_gray),
        .empty            (empty)
    );

    dualport_ram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_ram (
        .wr_clk  (wr_clk),
        .wr_en   (wr_en & ~full),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

    // ── reset tracking ────────────────────────────────────────────────
    // Wait until both domains have been out of reset for several cycles
    // before checking properties -- the synchronizer latency means flags
    // take a few cycles to stabilize after reset release.
    reg [3:0] wr_rst_cnt = 0;
    reg [3:0] rd_rst_cnt = 0;

    always @(posedge wr_clk)
        if (!wr_rst_n) wr_rst_cnt <= 0;
        else if (!wr_rst_cnt[3]) wr_rst_cnt <= wr_rst_cnt + 1;

    always @(posedge rd_clk)
        if (!rd_rst_n) rd_rst_cnt <= 0;
        else if (!rd_rst_cnt[3]) rd_rst_cnt <= rd_rst_cnt + 1;

    wire past_reset = wr_rst_cnt[3] & rd_rst_cnt[3];

    // ── assume: no activity during reset ─────────────────────────────
    always @(*) begin
        if (!wr_rst_n) assume(wr_en == 0);
        if (!rd_rst_n) assume(rd_en == 0);
        if (past_reset) begin
            assume(wr_rst_n == 1);
            assume(rd_rst_n == 1);
        end
    end

    // ── P1: full and empty never both asserted in steady state ────────
    always @(posedge wr_clk)
        if (past_reset) assert(!(full && empty));

    // ── P2: empty means read pointer has caught up to write pointer ───
    always @(posedge rd_clk)
        if (past_reset && empty)
            assert(rd_ptr_gray == $past(wr_ptr_gray_rd));

    // ── P3: full means Cummings MSB-inversion condition holds ─────────
    always @(posedge wr_clk)
        if (past_reset && full)
            assert(wr_ptr_gray ==
                   {~$past(rd_ptr_gray_wr[ADDR_WIDTH:ADDR_WIDTH-1]),
                     $past(rd_ptr_gray_wr[ADDR_WIDTH-2:0])});

endmodule
`default_nettype wire
