// dualport_ram.v
//
// Shared storage for the FIFO. Synchronous write (standard for real
// memory), combinational (asynchronous) read for simplicity -- this
// matches how Cummings' own reference implementation models the array.
// At this depth (a handful of entries) this will synthesize as a small
// flop-based array, not a dedicated SRAM macro, which is exactly what we
// want for the LibreLane flow later.

module dualport_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3
) (
    input  wire                   wr_clk,
    input  wire                   wr_en,
    input  wire [ADDR_WIDTH-1:0]  wr_addr,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire [ADDR_WIDTH-1:0]  rd_addr,
    output wire [DATA_WIDTH-1:0]  rd_data
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always @(posedge wr_clk) begin
        if (wr_en) mem[wr_addr] <= wr_data;
    end

    assign rd_data = mem[rd_addr];

endmodule
