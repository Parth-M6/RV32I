module DataMemory #(
    parameter [31:0] DEPTH = 256
) (
    input clk,
    input we,
    input MemRead,
    input [2:0] funct3,
    input [31:0] address,
    input [31:0] wd,
    output [31:0] rd
);
    reg [31:0] memory[0:DEPTH-1];

    wire [1:0] byte_offset = address[1:0];
    wire [29:0] word_idx = address[31:2];

    //Initialize memory to 0 to avoid X propagation during simulation
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            memory[i] = 32'd0;
        end
    end

    //Simulation assertions
    always @(*) begin
        //Check alignment on read/write accesses when memory is being accessed
        if (we || MemRead) begin
            //Word access check (LW, SW)
            if ((funct3 == 3'b010) && (byte_offset != 2'b00)) begin
                $display("ASSERTION FAILED: Misaligned word access at address %h", address);
            end
            //Halfword access check (LH, LHU, SH)
            if ((funct3 == 3'b001 || funct3 == 3'b101) && (byte_offset[0] != 1'b0)) begin
                $display("ASSERTION FAILED: Misaligned halfword access at address %h", address);
            end
        end
    end

    always @(posedge clk) begin
        if (we) begin
            if (word_idx >= DEPTH) begin
                $display("ASSERTION FAILED: Out-of-bounds write to address %h (word index %d, depth %d)", address, word_idx, DEPTH);
            end else begin
                case (funct3)
                    3'b000: begin //SB (Store Byte)
                        case (byte_offset)
                            2'b00: memory[word_idx] <= {memory[word_idx][31:8], wd[7:0]};
                            2'b01: memory[word_idx] <= {memory[word_idx][31:16], wd[7:0], memory[word_idx][7:0]};
                            2'b10: memory[word_idx] <= {memory[word_idx][31:24], wd[7:0], memory[word_idx][15:0]};
                            default: memory[word_idx] <= {wd[7:0], memory[word_idx][23:0]};
                        endcase
                    end
                    3'b001: begin //SH (Store Halfword)
                        case(byte_offset)
                            2'b00: memory[word_idx] <= {memory[word_idx][31:16], wd[15:0]};
                            default: memory[word_idx] <= {wd[15:0], memory[word_idx][15:0]};
                        endcase
                    end
                    3'b010: begin //SW (Store Word)
                        memory[word_idx] <= wd; 
                    end
                    default: memory[word_idx] <= wd;
                endcase
            end
        end
    end

    //Continuous assignment for loads
    wire [31:0] raw_word = (word_idx < DEPTH) ? memory[word_idx] : 32'hxxxxxxxx;

    wire [31:0] lb_val = (byte_offset == 2'b00) ? {{24{raw_word[7]}}, raw_word[7:0]} :
                         (byte_offset == 2'b01) ? {{24{raw_word[15]}}, raw_word[15:8]} :
                         (byte_offset == 2'b10) ? {{24{raw_word[23]}}, raw_word[23:16]} :
                                                  {{24{raw_word[31]}}, raw_word[31:24]};

    wire [31:0] lh_val = (byte_offset[1] == 1'b0) ? {{16{raw_word[15]}}, raw_word[15:0]} :
                                                    {{16{raw_word[31]}}, raw_word[31:16]};

    wire [31:0] lbu_val = (byte_offset == 2'b00) ? {24'b0, raw_word[7:0]} :
                          (byte_offset == 2'b01) ? {24'b0, raw_word[15:8]} :
                          (byte_offset == 2'b10) ? {24'b0, raw_word[23:16]} :
                                                   {24'b0, raw_word[31:24]};

    wire [31:0] lhu_val = (byte_offset[1] == 1'b0) ? {16'b0, raw_word[15:0]} :
                                                     {16'b0, raw_word[31:16]};

    assign rd = (!MemRead) ? 32'd0 :
                (word_idx >= DEPTH) ? 32'hxxxxxxxx :
                (funct3 == 3'b000) ? lb_val :
                (funct3 == 3'b001) ? lh_val :
                (funct3 == 3'b010) ? raw_word :
                (funct3 == 3'b100) ? lbu_val :
                (funct3 == 3'b101) ? lhu_val :
                raw_word;
endmodule
