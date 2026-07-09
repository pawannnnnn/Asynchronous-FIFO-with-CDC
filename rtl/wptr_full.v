// wptr_full.v
//
// Write-side pointer logic + FULL flag generation.
//
// Keeps a binary pointer (for addressing the RAM) and its Gray-coded
// twin (for crossing into the read domain). FULL is detected by comparing
// the write pointer's Gray code against the read pointer's Gray code
// (already synchronized into this domain) with its top two bits inverted --
// this is Cummings' standard trick: with one extra "wrap" bit on top of
// the address width, full and empty end up differing only in those two
// MSBs, so no separate wrap-counter or subtraction logic is needed.

module wptr_full #(
    parameter ADDR_WIDTH = 3
) (
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH:0]   rd_ptr_gray_sync,  // read pointer's gray code, synced into wr_clk domain
    output wire [ADDR_WIDTH-1:0] wr_addr,
    output reg  [ADDR_WIDTH:0]   wr_ptr_gray,       // this domain's gray pointer, goes out to be synced into read domain
    output reg                   full
);

    reg  [ADDR_WIDTH:0] wr_ptr_bin;
    wire [ADDR_WIDTH:0] wr_ptr_bin_next;
    wire [ADDR_WIDTH:0] wr_ptr_gray_next;
    wire                full_next;

    assign wr_ptr_bin_next = wr_ptr_bin + (wr_en & ~full);
    assign wr_addr          = wr_ptr_bin[ADDR_WIDTH-1:0];

    bin2gray #(.WIDTH(ADDR_WIDTH+1)) u_bin2gray (
        .bin  (wr_ptr_bin_next),
        .gray (wr_ptr_gray_next)
    );

    assign full_next = (wr_ptr_gray_next ==
                         {~rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1],
                           rd_ptr_gray_sync[ADDR_WIDTH-2:0]});

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
            full        <= 1'b0;
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            full        <= full_next;
        end
    end

endmodule
