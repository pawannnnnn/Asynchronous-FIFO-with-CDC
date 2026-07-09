`timescale 1ns/1ps

module tb_sync_2ff;
    parameter WIDTH = 4;
    reg              clk;
    reg              rst_n;
    reg  [WIDTH-1:0] d_in;
    wire [WIDTH-1:0] d_out;
    integer errors = 0;

    sync_2ff #(.WIDTH(WIDTH)) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .d_in  (d_in),
        .d_out (d_out)
    );

    // destination-domain clock: 10ns period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sync_2ff.vcd");
        $dumpvars(0, tb_sync_2ff);

        clk   = 0;
        rst_n = 0;
        d_in  = 4'h0;

        #12 rst_n = 1;          // release reset, deliberately NOT aligned to a clock edge

        // Change d_in asynchronously (mid-cycle, unrelated to clk edges),
        // then wait a full two clock periods (20ns) plus margin before checking.
        #7  d_in = 4'hA;        // t=19
        #25;                    // give it 2+ full clock periods to propagate
        if (d_out !== 4'hA) begin
            errors = errors + 1;
            $display("FAIL: expected d_out=A, got %h at t=%0t", d_out, $time);
        end else begin
            $display("PASS: d_out correctly became A by t=%0t", $time);
        end

        #7  d_in = 4'h5;
        #25;
        if (d_out !== 4'h5) begin
            errors = errors + 1;
            $display("FAIL: expected d_out=5, got %h at t=%0t", d_out, $time);
        end else begin
            $display("PASS: d_out correctly became 5 by t=%0t", $time);
        end

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

    initial $monitor("t=%0t clk=%b rst_n=%b d_in=%h stage1=%h d_out=%h",
                      $time, clk, rst_n, d_in, dut.stage1, d_out);

endmodule
