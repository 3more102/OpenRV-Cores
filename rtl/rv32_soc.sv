// SPDX-License-Identifier: MIT
// Simulation-only SoC wrapper. Replace inferred arrays with FPGA RAM/IP for deployment.
module rv32_soc (
    input  logic clk_i,
    input  logic rst_ni,
    output logic halted_o,
    output logic [2:0] halt_reason_o
);
    logic [31:0] instr_addr, instr_data;
    logic        data_valid, data_we;
    logic [3:0]  data_wstrb;
    logic [31:0] data_addr, data_wdata, data_rdata;
    logic [31:0] imem [0:255];
    logic [31:0] dmem [0:255];
    integer i, j;
    reg [1023:0] program_file;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            imem[i] = 32'h00100073; // EBREAK padding
            dmem[i] = 32'b0;
        end
        if (!$value$plusargs("PROGRAM=%s", program_file))
            program_file = "tests/smoke.hex";
        $display("Loading program: %0s", program_file);
        $readmemh(program_file, imem);
    end

    assign instr_data = (instr_addr < 32'd1024) ? imem[instr_addr[9:2]] : 32'h00100073;
    assign data_rdata = (data_addr < 32'd1024) ? dmem[data_addr[9:2]] : 32'b0;

    always @(posedge clk_i) begin
        if (rst_ni && data_valid && data_we) begin
            if (data_addr < 32'd1024) begin
                for (j = 0; j < 4; j = j + 1)
                    if (data_wstrb[j])
                        dmem[data_addr[9:2]][8*j +: 8] <= data_wdata[8*j +: 8];
            end else begin
                $fatal(1, "Out-of-range data write: %h", data_addr);
            end
        end
    end

    rv32_core cpu (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .instr_addr_o(instr_addr), .instr_rdata_i(instr_data),
        .data_valid_o(data_valid), .data_we_o(data_we),
        .data_wstrb_o(data_wstrb), .data_addr_o(data_addr),
        .data_wdata_o(data_wdata), .data_rdata_i(data_rdata),
        .halted_o(halted_o), .halt_reason_o(halt_reason_o)
    );
endmodule
