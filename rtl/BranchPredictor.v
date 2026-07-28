module BranchPredictor #(parameter INDEX_BITS = 8 )(
    input clk,
    input reset,
    
    input [31:0] lookup_pc,
    output predict_taken,
    output [31:0] predict_target,

    //Training port (driven from EX stage, once the real outcome is known)
    input             update_en,       //only asserted for actual branch/JAL/JALR instructions
    input      [31:0] update_pc,       //PC of the instruction being resolved in EX
    input             actual_taken,
    input      [31:0] actual_target
);

    localparam ENTRIES  = (1 << INDEX_BITS);
    localparam TAG_BITS = 32 - INDEX_BITS - 2; //drop 2 lsb (word aligned)

    reg                 valid   [0:ENTRIES-1];
    reg [TAG_BITS-1:0]  tag     [0:ENTRIES-1];
    reg [31:0]          target  [0:ENTRIES-1];
    reg [1:0]           counter [0:ENTRIES-1]; //2-bit saturating counter (Smith predictor)

    //Lookup (IF stage)
    wire [INDEX_BITS-1:0] lookup_idx = lookup_pc[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   lookup_tag = lookup_pc[31:INDEX_BITS+2];
    wire                  lookup_hit = valid[lookup_idx] && (tag[lookup_idx] == lookup_tag);

    assign predict_taken  = lookup_hit && counter[lookup_idx][1]; //MSB=1 => predict taken
    assign predict_target = target[lookup_idx];

    //Training (EX stage)
    wire [INDEX_BITS-1:0] update_idx = update_pc[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   update_tag = update_pc[31:INDEX_BITS+2];
    wire                  update_hit = valid[update_idx] && (tag[update_idx] == update_tag);

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid[i]   <= 1'b0;
                counter[i] <= 2'b01; //weakly-not-taken (irrelevant while invalid)
            end
        end else if (update_en) begin
            if (actual_taken) begin
                if (update_hit) begin
                    //Same address seen before: refresh target (handles JALR whose target can legitimately change between calls) and saturate up.
                    target[update_idx]  <= actual_target;
                    counter[update_idx] <= (counter[update_idx] == 2'b11) ? 2'b11
                                                                           : counter[update_idx] + 2'b01;
                end else begin
                    //Cold entry or address conflict: allocate fresh, start weakly-taken.
                    valid[update_idx]   <= 1'b1;
                    tag[update_idx]     <= update_tag;
                    target[update_idx]  <= actual_target;
                    counter[update_idx] <= 2'b10;
                end
            end else begin
                //Resolved not-taken. Only decay an entry that is actually tracking this PC; never allocate an entry purely for a not-taken outcome (keeps "never seen taken" == "predict not-taken" by construction).
                if (update_hit) begin
                    counter[update_idx] <= (counter[update_idx] == 2'b00) ? 2'b00: counter[update_idx] - 2'b01;
                end
            end
        end
    end

endmodule
