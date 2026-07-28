module PCMux(
    input [31:0] pc_plus_4,
    input predict_taken,          //BTB prediction for the address currently being fetched
    input [31:0] predict_target,
    input Misprediction,          //from EX stage: overrides everything, redirects fetch
    input [31:0] CorrectedTarget, //resolved-correct next PC when Misprediction is set
    output reg [31:0] pc_next
);

    always @(*) begin
        if (Misprediction) begin
            pc_next = CorrectedTarget;
        end else if (predict_taken) begin
            pc_next = predict_target;
        end else begin
            pc_next = pc_plus_4;
        end
    end

endmodule
