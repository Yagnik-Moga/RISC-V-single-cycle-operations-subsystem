class riscv_transaction;

    // ==========================================================
    // Instruction information
    // ==========================================================

    logic [31:0] pc;
    logic [31:0] instr;

    // ==========================================================
    // Execution information
    // ==========================================================

    logic [31:0] alu_result;
    logic [31:0] writeback_data;

    logic [4:0]  rd_addr;

    // ==========================================================
    // Control information
    // ==========================================================

    logic RegWrite;
    logic MemWrite;
    logic MemRead;
    logic MemtoReg;
    logic Branch;
    logic Jump;


    // ==========================================================
    // Display transaction
    // ==========================================================

    function void display(string name);

        $display(
            "[%s] PC: 0x%08h | Instr: 0x%08h | RD: x%0d | " ,
            name,
            pc,
            instr,
            rd_addr
        );

        $display(
            "       ALU: 0x%08h | WB: 0x%08h | " ,
            alu_result,
            writeback_data
        );

        $display(
            "RegWrite=%b MemWrite=%b MemRead=%b " ,
            RegWrite,
            MemWrite,
            MemRead
        );

        $display(
            "MemtoReg=%b Branch=%b Jump=%b",
            MemtoReg,
            Branch,
            Jump
        );

    endfunction

endclass
