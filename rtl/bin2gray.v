// bin2gray.v
//
// Combinational binary-to-Gray-code converter.
// Gray code has the property that consecutive values differ in exactly
// one bit -- that's the whole reason it exists in this design: it's what
// makes a multi-bit pointer safe to carry through a 2FF synchronizer.

module bin2gray #(
    parameter WIDTH = 4
) (
    input  wire [WIDTH-1:0] bin,
    output wire [WIDTH-1:0] gray
);

    assign gray = bin ^ (bin >> 1);

endmodule
