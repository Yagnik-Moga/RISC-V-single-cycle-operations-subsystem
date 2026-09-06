interface riscv_if(input logic clk);

    logic reset;

    // ==========================================================
    // DUT signals exposed to the testbench
    // ==========================================================

    logic [31:0] pc;
    logic [31:0] instr;
    logic [31:0] alu_result;

    logic        RegWrite;
    logic        MemWrite;
    logic        MemRead;
    logic        MemtoReg;
    logic        Branch;
    logic        Jump;

    logic [4:0]  rd_addr;

    logic [31:0] writeback_data;


    // ==========================================================
    // Clocking block
    // ==========================================================

    clocking cb @(posedge clk);

        default input #1ns output #1ns;

        input pc;
        input instr;
        input alu_result;

        input RegWrite;
        input MemWrite;
        input MemRead;
        input MemtoReg;
        input Branch;
        input Jump;

        input rd_addr;
        input writeback_data;

        output reset;

    endclocking

endinterface
