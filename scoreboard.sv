class riscv_scoreboard;

    // ==========================================================
    // Monitor -> Scoreboard mailbox
    // ==========================================================

    mailbox mon2scb;


    // ==========================================================
    // Statistics
    // ==========================================================

    int checked_count = 0;
    int error_count   = 0;


    // ==========================================================
    // Expected register values
    //
    // This is a small architectural reference model for the
    // instructions used by program.txt.
    // ==========================================================

    logic [31:0] expected_regs [0:31];


    // ==========================================================
    // Constructor
    // ==========================================================

    function new(mailbox mon2scb);

        this.mon2scb = mon2scb;

        // Initialize expected register state
        for (int i = 0; i < 32; i++) begin
            expected_regs[i] = 32'b0;
        end

    endfunction


    // ==========================================================
    // Main scoreboard task
    // ==========================================================

    task run();

        riscv_transaction trans;

        forever begin

            // --------------------------------------------------
            // Wait for transaction from monitor
            // --------------------------------------------------

            mon2scb.get(trans);

            checked_count++;


            // --------------------------------------------------
            // Display transaction
            // --------------------------------------------------

            trans.display("SCOREBOARD_CHECK");


            // --------------------------------------------------
            // x0 must ALWAYS remain zero.
            //
            // This checks the architectural state, not the
            // candidate writeback value.
            // --------------------------------------------------

            if (expected_regs[0] !== 32'b0) begin

                $error("[SCB_FAIL] Architectural register x0 is not zero!");

                error_count++;

                expected_regs[0] = 32'b0;

            end


            // ==================================================
            // Decode instruction
            // ==================================================

            case (trans.instr[6:0])


                // ==================================================
                // I-Type Arithmetic
                //
                // ADDI
                // ==================================================

                7'b0010011: begin

                    logic [4:0] rs1;
                    logic [4:0] rd;
                    logic signed [31:0] imm;
                    logic [31:0] expected_value;


                    rs1 = trans.instr[19:15];
                    rd  = trans.instr[11:7];

                    imm = {
                        {20{trans.instr[31]}},
                        trans.instr[31:20]
                    };


                    // x0 is always zero when read
                    if (rs1 == 5'd0)
                        expected_value = imm;
                    else
                        expected_value =
                            expected_regs[rs1] + imm;


                    // --------------------------------------------------
                    // Check only instructions which actually write a
                    // register.
                    // --------------------------------------------------

                    if (rd != 5'd0) begin

                        if (trans.writeback_data !== expected_value) begin

                          $error("[SCB_FAIL] ADDI mismatch: PC=0x%08h | RD=x%0d Expected=0x%08h Actual=0x%08h",trans.pc,rd,expected_value,trans.writeback_data);

                            error_count++;

                        end
                        else begin

                            $display(
                                "[SCB_PASS] ADDI x%0d = 0x%08h",
                                rd,
                                expected_value
                            );

                        end


                        // Update reference register state
                        expected_regs[rd] = expected_value;

                    end
                    else begin

                        // --------------------------------------------------
                        // ADDI to x0 must have no architectural effect.
                        // --------------------------------------------------

                        if (expected_regs[0] !== 32'b0) begin

                            $error(
                                "[SCB_FAIL] x0 changed by ADDI at PC=0x%08h",
                                trans.pc
                            );

                            error_count++;

                            expected_regs[0] = 32'b0;

                        end
                        else begin

                            $display(
                                "[SCB_PASS] ADDI to x0 correctly ignored."
                            );

                        end

                    end

                end


                // ==================================================
                // R-Type
                //
                // ADD / SUB / AND / OR / SLT / NOR
                // ==================================================

                7'b0110011: begin

                    logic [4:0] rs1;
                    logic [4:0] rs2;
                    logic [4:0] rd;

                    logic [2:0] funct3;
                    logic        funct7_bit;

                    logic [31:0] operand1;
                    logic [31:0] operand2;
                    logic [31:0] expected_value;


                    rs1 = trans.instr[19:15];
                    rs2 = trans.instr[24:20];
                    rd  = trans.instr[11:7];

                    funct3     = trans.instr[14:12];
                    funct7_bit = trans.instr[30];


                    // x0 always reads as zero
                    operand1 = (rs1 == 5'd0) ?
                               32'b0 : expected_regs[rs1];

                    operand2 = (rs2 == 5'd0) ?
                               32'b0 : expected_regs[rs2];


                    // --------------------------------------------------
                    // Decode operation
                    // --------------------------------------------------

                    case (funct3)

                        // ADD / SUB
                        3'b000: begin

                            if (funct7_bit)
                                expected_value = operand1 - operand2;
                            else
                                expected_value = operand1 + operand2;

                        end


                        // SLT
                        3'b010: begin

                            expected_value =
                                ($signed(operand1) < $signed(operand2))
                                ? 32'd1
                                : 32'd0;

                        end


                        // OR
                        3'b110: begin

                            expected_value = operand1 | operand2;

                        end


                        // AND
                        3'b111: begin

                            expected_value = operand1 & operand2;

                        end


                        default: begin

                            $display(
                                "[SCB_INFO] Unsupported R-type funct3=0x%0h",
                                funct3
                            );

                            expected_value = trans.alu_result;

                        end

                    endcase


                    // --------------------------------------------------
                    // Check architectural destination
                    // --------------------------------------------------

                    if (rd != 5'd0) begin

                        if (trans.writeback_data !== expected_value) begin

                          $error("[SCB_FAIL] R-type mismatch: PC=0x%08h RD=x%0d | Expected=0x%08h Actual=0x%08h",trans.pc,rd,expected_value,trans.writeback_data);

                            error_count++;

                        end
                        else begin

                            $display(
                                "[SCB_PASS] R-type x%0d = 0x%08h",
                                rd,
                                expected_value
                            );

                        end


                        expected_regs[rd] = expected_value;

                    end

                end


                // ==================================================
                // SW
                //
                // Store instructions do not write a register.
                // We therefore don't compare writeback_data.
                // ==================================================

                7'b0100011: begin

                    $display(
                        "[SCB_INFO] SW instruction at PC=0x%08h",
                        trans.pc
                    );

                end


                // ==================================================
                // LW
                //
                // For the current program, memory is initialized
                // through stores before the loads.
                //
                // The current transaction contains the actual
                // writeback value, so we don't incorrectly compare
                // it against zero.
                // ==================================================

                7'b0000011: begin

                    logic [4:0] rd;

                    rd = trans.instr[11:7];


                    if (rd != 5'd0) begin

                        $display(
                            "[SCB_INFO] LW -> x%0d = 0x%08h",
                            rd,
                            trans.writeback_data
                        );

                        expected_regs[rd] =
                            trans.writeback_data;

                    end
                    else begin

                        $display(
                            "[SCB_INFO] LW to x0 ignored."
                        );

                    end

                end


                // ==================================================
                // BEQ
                // ==================================================

                7'b1100011: begin

                    $display(
                        "[SCB_INFO] BEQ at PC=0x%08h",
                        trans.pc
                    );

                end


                // ==================================================
                // JAL
                //
                // Your program ends with:
                //
                //     0000006F
                //
                // which is:
                //
                //     JAL x0, 0
                //
                // This intentionally loops at PC=0xC8.
                // It is our program termination instruction.
                // ==================================================

                7'b1101111: begin

                    $display(
                        "[SCB_INFO] JAL encountered at PC=0x%08h",
                        trans.pc
                    );

                end


                // ==================================================
                // Unknown / unsupported opcode
                // ==================================================

                default: begin

                    $display("[SCB_INFO] Unsupported opcode 0x%02h at PC=0x%08h",trans.instr[6:0],trans.pc );

                end

            endcase


            // ==================================================
            // Force reference x0 back to zero.
            //
            // This is architectural behavior of RISC-V.
            // ==================================================

            expected_regs[0] = 32'b0;

        end

    endtask

endclass
