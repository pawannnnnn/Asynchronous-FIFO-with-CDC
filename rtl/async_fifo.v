// async_fifo.v
//
// Top-level: wires the two pointer/flag modules, the two 2FF
// synchronizers (one per crossing direction), and the shared RAM into a
// complete dual-clock FIFO.

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3
) (
    // write domain
    input  wire                   wr_clk,
    input  wire                   wr_rst_n,
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    output wire                   full,
    // read domain
    input  wire                   rd_clk,
    input  wire                   rd_rst_n,
    input  wire                   rd_en,
    output wire [DATA_WIDTH-1:0]  rd_data,
    output wire                   empty
);

    wire [ADDR_WIDTH:0]   wr_ptr_gray, rd_ptr_gray;
    wire [ADDR_WIDTH:0]   wr_ptr_gray_rd, rd_ptr_gray_wr;
    wire [ADDR_WIDTH-1:0] wr_addr, rd_addr;

    // write pointer's gray code, synchronized into the read domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_wr2rd (
        .clk   (rd_clk),
        .rst_n (rd_rst_n),
        .d_in  (wr_ptr_gray),
        .d_out (wr_ptr_gray_rd)
    );

    // read pointer's gray code, synchronized into the write domain
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

endmodule
