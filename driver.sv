class riscv_driver;

    // ==========================================================
    // Virtual interface
    // ==========================================================

    virtual riscv_if vif;


    // ==========================================================
    // Constructor
    // ==========================================================

    function new(virtual riscv_if vif);

        this.vif = vif;

    endfunction


    // ==========================================================
    // Reset sequence
    // ==========================================================

    task reset_dut();

        $display("[DRIVER] Asserting system reset...");

        // Assert reset
        vif.reset <= 1'b1;


        // ------------------------------------------------------
        // Hold reset for 3 complete clock cycles
        // ------------------------------------------------------

        repeat (3)
            @(posedge vif.clk);


        // ------------------------------------------------------
        // Release reset cleanly
        //
        // Use the clocking block so reset release is
        // synchronized with the testbench clock.
        // ------------------------------------------------------

        $display("[DRIVER] Deasserting reset. Processor starting execution...");

        vif.cb.reset <= 1'b0;


        // Wait for the next clock edge before returning.
        // This prevents the driver and monitor from racing
        // around reset release.
        @(posedge vif.clk);

    endtask


    // ==========================================================
    // Main driver task
    // ==========================================================

    task run();

        reset_dut();

        $display("[DRIVER] Reset sequence completed.");
        $display("[DRIVER] CPU is now running.");

    endtask

endclass
