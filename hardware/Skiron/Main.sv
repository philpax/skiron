module Main
(
    input           CLOCK_50,
    input   [2:0]   SW,
    output  [7:0]   LEDG
);
    parameter TestOpcode = 32'b11000110_00000000_00111011_10001000;

    wire [5:0]  opcode;
    wire [1:0]  encoding;
    wire [1:0]  variant;

    wire [5:0]  register1;
    wire [5:0]  register2;
    wire [5:0]  register3;
    wire [15:0] immediateU16;
    wire [19:0] immediateS20;
    wire [7:0]  immediateS8;

    wire [1:0]  operandSize;

    OpcodeDecoder opcodeDecoder
    (
        .Opcode         (TestOpcode),
        .Clock          (CLOCK_50),

        .opcode         (opcode),
        .encoding       (encoding),
        .variant        (variant),

        .register1      (register1),
        .register2      (register2),
        .register3      (register3),

        .immediateU16   (immediateU16),
        .immediateS20   (immediateS20),
        .immediateS8    (immediateS8),

        .operandSize    (operandSize)
    );

    always_ff @(posedge CLOCK_50) begin
        case (SW[2:0])
            3'b000: LEDG <= opcode;
            3'b001: LEDG <= encoding;
            3'b010: LEDG <= variant;
            3'b011: LEDG <= register1;
            3'b100: LEDG <= register2;
            3'b101: LEDG <= immediateS8;
            3'b110: LEDG <= operandSize;
            3'b111: LEDG <= 8'b1111_1111;
        endcase
    end
endmodule