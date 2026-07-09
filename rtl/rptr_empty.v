// rptr_empty.v
//
// Read-side pointer logic + EMPTY flag generation.
//
// Mirrors wptr_full. EMPTY is detected by direct equality: if the read
// pointer's Gray code (about to be reached) exactly matches the write
// pointer's Gray code (synced into this domain), the read side has fully
// caught up and there is nothing left to read.

module rptr_empty #(
    parameter ADDR_WIDTH = 3
) (
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    input  wire [ADDR_WIDTH:0]   wr_ptr_gray_sync,  // write pointer's gray code, synced into rd_clk domain
    output wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [ADDR_WIDTH:0]   rd_ptr_gray,
    output reg                   empty
);

    reg  [ADDR_WIDTH:0] rd_ptr_bin;
    wire [ADDR_WIDTH:0] rd_ptr_bin_next;
    wire [ADDR_WIDTH:0] rd_ptr_gray_next;
    wire                empty_next;

    assign rd_ptr_bin_next = rd_ptr_bin + (rd_en & ~empty);
    assign rd_addr          = rd_ptr_bin[ADDR_WIDTH-1:0];

    bin2gray #(.WIDTH(ADDR_WIDTH+1)) u_bin2gray (
        .bin  (rd_ptr_bin_next),
        .gray (rd_ptr_gray_next)
    );

    assign empty_next = (rd_ptr_gray_next == wr_ptr_gray_sync);

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
            empty       <= 1'b1;
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
            empty       <= empty_next;
        end
    end

endmodule
