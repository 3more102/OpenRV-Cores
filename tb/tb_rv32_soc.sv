`timescale 1ns/1ps
// Self-checking testbench; individual programs chosen via +TEST and +PROGRAM.
module tb_rv32_soc;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire halted;
    wire [2:0] halt_reason;
    integer cycles;
    integer test_id;

    always #5 clk = ~clk;

    rv32_soc dut (
        .clk_i(clk), .rst_ni(rst_n),
        .halted_o(halted), .halt_reason_o(halt_reason)
    );

    task expect_reg(input integer idx, input [31:0] expected);
        begin
            if (dut.cpu.regs[idx] !== expected)
                $fatal(1, "x%0d actual=%h expected=%h", idx, dut.cpu.regs[idx], expected);
        end
    endtask

    task expect_dmem(input integer idx, input [31:0] expected);
        begin
            if (dut.dmem[idx] !== expected)
                $fatal(1, "DMEM[%0d] actual=%h expected=%h", idx, dut.dmem[idx], expected);
        end
    endtask

    initial begin
        if (!$value$plusargs("TEST=%d", test_id)) test_id = 1;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        for (cycles = 0; cycles < 120; cycles = cycles + 1) begin
            @(negedge clk);
            if (halted) begin
                expect_reg(0, 32'd0);
                case (test_id)
                    1: begin // smoke
                        expect_reg(1, 5); expect_reg(2, 7); expect_reg(3, 12);
                        expect_reg(4, 12); expect_reg(5, 42); expect_reg(6, 36);
                        expect_reg(7, 11); expect_reg(8, 32'h12345000);
                        expect_reg(9, 48); expect_reg(10, 5);
                        expect_reg(11, 32'h0000050c); expect_reg(12, 1);
                        expect_reg(13, 20); expect_reg(14, 2);
                        expect_dmem(0, 32'h0000050c);
                    end
                    2: begin // branches and shifts
                        expect_reg(1, 32'hffffffff); expect_reg(2, 1);
                        expect_reg(3, 0); expect_reg(4, 32'hffffffff);
                        expect_reg(5, 32'h7fffffff); expect_reg(6, 1);
                        expect_reg(7, 3); expect_reg(8, 48);
                        expect_reg(9, 44); expect_reg(10, 8); expect_reg(11, 1);
                    end
                    3: begin // memory widths, signed/unsigned, lane masks
                        expect_reg(1, 32'hffffff80); expect_reg(2, 32'hffffff80);
                        expect_reg(3, 32'h80); expect_reg(4, 32'hffffff80);
                        expect_reg(5, 32'hff80); expect_reg(6, 32'h123);
                        expect_reg(7, 32'h123); expect_reg(8, 32'h123);
                        expect_reg(9, 32'h23); expect_reg(10, 32'h01232380);
                        expect_dmem(0, 32'h01232380);
                    end
                    4: begin // arithmetic and bitwise operations
                        expect_reg(1, 32'hfffffff8); expect_reg(2, 3);
                        expect_reg(3, 32'hfffffffb); expect_reg(4, 11);
                        expect_reg(5, 24); expect_reg(6, 32'h1fffffff);
                        expect_reg(7, 32'hffffffff); expect_reg(8, 1);
                        expect_reg(9, 0); expect_reg(10, 32'hfffffffb);
                        expect_reg(11, 0); expect_reg(12, 32'hfffffffb);
                        expect_reg(13, 32'hffffffad); expect_reg(14, 0);
                        expect_reg(15, 32'h43); expect_reg(16, 48);
                        expect_reg(17, 32'h3ffffffe);
                        expect_reg(18, 32'hfffffffe); expect_reg(19, 1);
                    end
                    5: begin // backward loop and all branch comparisons
                        expect_reg(1, 3); expect_reg(2, 3);
                        expect_reg(3, 7); expect_reg(4, 8);
                        expect_reg(5, 9); expect_reg(6, 10); expect_reg(7, 11);
                    end
                    6: expect_reg(1, 5); // illegal opcode
                    7: begin expect_reg(1, 1); expect_reg(2, 0); end
                    8: expect_reg(1, 0); // ECALL
                    9: begin expect_reg(1, 6); expect_reg(2, 0); end
                    10: begin expect_reg(1, 3); expect_reg(2, 0); end
                    default: $fatal(1, "Unsupported TEST=%0d", test_id);
                endcase
                if (test_id == 6 || test_id == 10) begin
                    if (halt_reason !== 3'd3) $fatal(1, "Expected illegal reason 3, got %d", halt_reason);
                end else if (test_id == 7) begin
                    if (halt_reason !== 3'd4) $fatal(1, "Expected misaligned data reason 4, got %d", halt_reason);
                end else if (test_id == 8) begin
                    if (halt_reason !== 3'd2) $fatal(1, "Expected ECALL reason 2, got %d", halt_reason);
                end else if (test_id == 9) begin
                    if (halt_reason !== 3'd5) $fatal(1, "Expected misaligned jump reason 5, got %d", halt_reason);
                end else begin
                    if (halt_reason !== 3'd1) $fatal(1, "Expected EBREAK reason 1, got %d", halt_reason);
                end
                $display("PASS: test %0d (%0d cycles), halt_reason=%0d", test_id, cycles + 1, halt_reason);
                $finish;
            end
        end
        $fatal(1, "TIMEOUT: processor did not halt");
    end
endmodule
