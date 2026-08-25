`timescale 1ns/1ps

module tb_cpu_diff;

    reg clk;
    reg reset;

    integer cycles;
    integer trace_file;

    CPU #(
        .IMEM_FILE("diff/rtl/instructions.hex")
    ) dut (
        .clk(clk),
        .reset(reset)
    );

    //CLK
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // Waveform
    initial begin
        $dumpfile("diff/rtl/diff.vcd");
        $dumpvars(0, tb_cpu_diff);
    end




    initial begin

        trace_file = $fopen("diff/rtl/rtl_trace.log", "w");

        if (trace_file == 0) begin
            $display("ERROR: Could not open RTL trace file");
            $finish;
        end

        cycles = 0;
        reset = 1;

        repeat (2) @(posedge clk);
        reset = 0;

        forever begin

            @(negedge clk);

            cycles = cycles + 1;

            //Ignore bubbles/NOPs inserted by the pipeline
            if (dut.wb_instruction !== 32'h00000013) begin

                if (dut.wb_RegWrite && (dut.wb_rd != 0)) begin

                    $fwrite(
                        trace_file,
                        "%08h %08h %02d %08h\n",
                        dut.wb_pc,
                        dut.wb_instruction,
                        dut.wb_rd,
                        dut.wb_wd3
                    );

                end
                else begin

                    $fwrite(
                        trace_file,
                        "%08h %08h 00 00000000\n",
                        dut.wb_pc,
                        dut.wb_instruction
                    );

                end
            end

            // Completion marker: addi x31, x0, 0x55 (0x05500f93)
            if (dut.wb_instruction === 32'h05500f93) begin

                $display("");
                $display("========================================");
                $display("      DIFFERENTIAL TEST FINISHED");
                $display("========================================");
                $display("Cycles : %0d", cycles);

                $fclose(trace_file);
                $finish;
            end

            // Timeout
            if (cycles > 20000) begin

                $display("");
                $display("========================================");
                $display("      DIFFERENTIAL TEST TIMEOUT");
                $display("========================================");

                $display("Cycles : %0d", cycles);

                $fclose(trace_file);
                $finish;
            end
        end
    end
endmodule
