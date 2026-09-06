`timescale 1ns / 1ps

// ==========================================================
// Forward declarations
// ==========================================================

typedef class riscv_transaction;
typedef class riscv_driver;
typedef class riscv_monitor;
typedef class riscv_scoreboard;
typedef class riscv_environment;


// ==========================================================
// Include verification blocks
// ==========================================================

`include "interface.sv"
`include "transaction.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"
`include "environment.sv"


// ==========================================================
// TOP TESTBENCH
// ==========================================================

module tb_top;

    // ==========================================================
    // Clock
    // ==========================================================

    logic clk;

    initial begin

        clk = 1'b0;

        forever
            #5 clk = ~clk;

    end


    // ==========================================================
    // Interface
    // ==========================================================

    riscv_if inf(clk);


    // ==========================================================
    // DUT
    // ==========================================================

    riscv_single_cycle DUT (

        .clk   (clk),
        .reset (inf.reset)

    );


    // ==========================================================
    // Connect DUT internal signals to verification interface
    // ==========================================================

    assign inf.pc             = DUT.pc;
    assign inf.instr          = DUT.instr;
    assign inf.alu_result     = DUT.alu_result;
    assign inf.RegWrite       = DUT.RegWrite;
    assign inf.rd_addr        = DUT.instr[11:7];
    assign inf.writeback_data = DUT.result_wb;


    // ==========================================================
    // Environment
    // ==========================================================

    riscv_environment env;


    // ==========================================================
    // Test sequence
    // ==========================================================

   initial begin

    // ------------------------------------------------
    // Waveform
    // ------------------------------------------------
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);


    // ------------------------------------------------
    // Load program
    // ------------------------------------------------
    $display("\n==============================================");
    $display("         LOADING RISC-V PROGRAM");
    $display("==============================================");

    $readmemh("program.txt", DUT.Instr_Mem.rom);

    $display("[TB] program.txt loaded into instruction memory.\n");


    // ------------------------------------------------
    // Create environment
    // ------------------------------------------------
    env = new(inf);


    // ------------------------------------------------
    // Run verification
    // This will wait for JAL x0,0
    // ------------------------------------------------
    env.run();


    // ------------------------------------------------
    // Normal completion
    // ------------------------------------------------
    $display("[TB] Simulation finished successfully.");

    $finish;

end

endmodule
