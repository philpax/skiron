module OpcodeDecoder
(
    input   [31:0]      Opcode,
    input               Clock,

    output wire [5:0]   opcode,
    output wire [1:0]   encoding,
    output wire [1:0]   variant,

    output wire [5:0]   register1,
    output wire [5:0]   register2,
    output wire [5:0]   register3,
    output wire [15:0]  immediateU16,
    output wire [19:0]  immediateS20,
    output wire [7:0]   immediateS8,

    output wire [1:0]   operandSize
);
    wire    [7:0] byte1 = Opcode[31:24];
    wire    [7:0] byte2 = Opcode[23:16];
    wire    [7:0] byte3 = Opcode[15:8];
    wire    [7:0] byte4 = Opcode[7:0];

    always_ff @(posedge Clock) begin
        opcode      <= byte1[5:0];
        encoding    <= byte1[7:6];
        variant     <= byte2[1:0];

        case (encoding)
            // Encoding A
            2'b00: begin
                register1       <=  byte2[7:2];
                register2       <=  byte3[5:0];
                register3       <= {byte4[3:0], byte3[7:6]};
                operandSize     <=  byte4[7:6];
            end

            // Encoding B
            2'b01: begin
                register1       <=  byte2[7:2];
                immediateU16    <= {byte4[7:0], byte3[7:0]};
            end

            // Encoding C
            2'b10: begin
                register1       <=  byte2[7:2];
                register2       <=  byte3[5:0];
                immediateS20    <= {byte4[5:0], byte3[7:0], byte2[7:2]};
                operandSize     <=  byte4[7:6];
            end

            // Encoding D
            2'b11: begin
                register1       <=  byte2[7:2];
                register2       <=  byte3[5:0];
                immediateS8     <= {byte4[5:0], byte3[7:6]};
                operandSize     <=  byte4[7:6];
            end
        endcase
    end
endmodule