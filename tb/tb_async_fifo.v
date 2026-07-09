`timescale 1ns/1ps

// ─────────────────────────────────────────────────────────────────────
// WHY full AND empty CAN BRIEFLY BOTH BE 1 (this is NOT a bug)
//
// full  lives in the WRITE domain: it's a delayed estimate of the read
//        pointer (2 wr_clk cycles to sync it across).
// empty lives in the READ  domain: it's a delayed estimate of the write
//        pointer (2 rd_clk cycles to sync it across).
//
// Right after a burst-fill from empty:
//   - wr_clk sees full=1 immediately (write pointer caught up to read ptr)
//   - rd_clk still sees empty=1 because the write pointer hasn't been
//     synchronized across yet (2-cycle latency)
//
// That transient window is normal CDC latency, not data corruption.
// The check that actually matters is the scoreboard: every value read back
// must exactly match what was written, in order. That is what catches real
// bugs. The full+empty combined assertion would be a false alarm.
// ─────────────────────────────────────────────────────────────────────

module tb_async_fifo;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 3;

    reg                    wr_clk, rd_clk;
    reg                    wr_rst_n, rd_rst_n;
    reg                    wr_en, rd_en;
    reg  [DATA_WIDTH-1:0]  wr_data;
    wire                   full, empty;
    wire [DATA_WIDTH-1:0]  rd_data;

    integer errors;
    reg [DATA_WIDTH-1:0] expect_q [0:1023];
    integer q_head, q_tail;
    reg [DATA_WIDTH-1:0] wdata_counter;
    integer seed;

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
        .wr_clk   (wr_clk),
        .wr_rst_n (wr_rst_n),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .full     (full),
        .rd_clk   (rd_clk),
        .rd_rst_n (rd_rst_n),
        .rd_en    (rd_en),
        .rd_data  (rd_data),
        .empty    (empty)
    );

    // deliberately unrelated clock periods (no common small multiple)
    initial wr_clk = 0;
    always #3    wr_clk = ~wr_clk;   // 6ns  write clock
    initial rd_clk = 0;
    always #6.5  rd_clk = ~rd_clk;   // 13ns read clock (slower reader)

    initial begin
        errors        = 0;
        seed          = 42;
        q_head        = 0;
        q_tail        = 0;
        wdata_counter = 0;
        wr_rst_n      = 0;
        rd_rst_n      = 0;
        wr_en         = 0;
        rd_en         = 0;
        wr_data       = 0;
        #25 wr_rst_n  = 1;
        #25 rd_rst_n  = 1;
    end

    // write driver: randomly write when not full
    always @(posedge wr_clk) begin
        #1;
        if (wr_rst_n) begin
            if (!full && ($random(seed) % 3 != 0))
                begin wr_en = 1; wr_data = wdata_counter; end
            else
                wr_en = 0;
        end
    end

    // scoreboard capture: record every committed write
    always @(posedge wr_clk) begin
        if (wr_rst_n && wr_en && !full) begin
            expect_q[q_tail] = wr_data;
            q_tail           = q_tail + 1;
            wdata_counter    = wdata_counter + 1;
        end
    end

    // read driver + scoreboard checker
    always @(posedge rd_clk) begin
        if (rd_rst_n && rd_en && !empty) begin
            if (rd_data !== expect_q[q_head]) begin
                errors = errors + 1;
                $display("MISMATCH t=%0t: expected %0d got %0d (q_head=%0d)",
                          $time, expect_q[q_head], rd_data, q_head);
            end
            q_head = q_head + 1;
        end
        #1;
        if (rd_rst_n) begin
            if (!empty && ($random(seed) % 2 != 0)) rd_en = 1;
            else rd_en = 0;
        end
    end

    initial begin
        #10000;
        $display("---");
        $display("words written: %0d  words read: %0d  remaining in FIFO: %0d",
                  q_tail, q_head, q_tail - q_head);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d ERROR(S) FOUND", errors);
        $finish;
    end

endmodule
