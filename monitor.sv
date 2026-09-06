class riscv_monitor;

    virtual riscv_if vif;
    mailbox mon2scb;

    // Event used to tell the environment that the program is finished
    event test_done;

    function new(virtual riscv_if vif,
                 mailbox mon2scb,
                 event test_done);

        this.vif      = vif;
        this.mon2scb  = mon2scb;
        this.test_done = test_done;

    endfunction


    task run();

        riscv_transaction trans;

        $display("[MONITOR] Started passive monitoring...");

        // Wait until reset is released
        @(negedge vif.reset);

        $display("[MONITOR] Reset released. Monitoring started.");

        forever begin

            // Sample on clock
            @(vif.cb);

            // Create transaction
            trans = new();

            // Capture DUT signals
            trans.pc             = vif.cb.pc;
            trans.instr          = vif.cb.instr;
            trans.alu_result     = vif.cb.alu_result;
            trans.rd_addr        = vif.cb.rd_addr;
            trans.writeback_data = vif.cb.writeback_data;

            // Send transaction to scoreboard
            mon2scb.put(trans);


            // ------------------------------------------------
            // END-OF-PROGRAM DETECTION
            // JAL x0, 0 = 32'h0000006F
            // ------------------------------------------------
            if (trans.instr == 32'h0000006F) begin

                $display("[MONITOR] Terminating instruction detected at PC = 0x%08h",
                         trans.pc);

                // Tell environment that program is finished
                -> test_done;

                $display("[MONITOR] Monitoring stopped.");

                break;
            end

        end

    endtask

endclass
