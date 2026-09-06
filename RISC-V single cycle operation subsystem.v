module alu (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  ALUControl,

    output reg  [31:0] Result,
    output wire        Zero
);

    // Zero flag
    assign Zero = (Result == 32'b0);

    always @(*) 
    begin
        case (ALUControl)
            4'b0000: Result = A & B;                          // AND
            4'b0001: Result = A | B;                          // OR
            4'b0010: Result = A + B;                          // ADD
            4'b0110: Result = A - B;                          // SUB
            4'b0111: Result = (A < B) ? 32'b1 : 32'b0;       // SLT
            4'b1100: Result = ~(A | B);                       // NOR

            default: Result = 32'b0;
        endcase
    end
endmodule

module register_file (
    input  wire        clk,
    input  wire        reset,
    input  wire        RegWrite,

    input  wire [4:0]  A1,
    input  wire [4:0]  A2,
    input  wire [4:0]  A3,

    input  wire [31:0] WD3,

    output wire [31:0] RD1,
    output wire [31:0] RD2
);

    // 32 registers, each 32 bits
    reg [31:0] rf [0:31];

    // --------------------------------------------------
    // Asynchronous reads
    // x0 is always read as zero
    // --------------------------------------------------

    assign RD1 = (A1 == 5'd0) ? 32'd0 : rf[A1];
    assign RD2 = (A2 == 5'd0) ? 32'd0 : rf[A2];

    // --------------------------------------------------
    // Synchronous write
    // x0 can never be written
    // --------------------------------------------------
    integer i;

    always @(posedge clk or posedge reset)
     begin
        if (reset)
         begin
            for (i = 0; i < 32; i = i + 1)
                rf[i] <= 32'd0;
        end

        else 
        begin
            if (RegWrite && (A3 != 5'd0))
                rf[A3] <= WD3;
        end
    end
endmodule


module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm_ext
);

    wire [6:0] opcode;

    assign opcode = instr[6:0];

    always @(*) begin

        case (opcode)

            // ------------------------------------------
            // I-Type
            // ADDI, LW
            // ------------------------------------------
            7'b0010011,
            7'b0000011: 
            begin
                imm_ext = {
                    {20{instr[31]}},
                    instr[31:20]
                };
            end

            // ------------------------------------------
            // S-Type
            // SW
            // ------------------------------------------
            7'b0100011: 
            begin
                imm_ext = {
                    {20{instr[31]}},
                    instr[31:25],
                    instr[11:7]
                };
            end

            // ------------------------------------------
            // B-Type
            // BEQ
            // ------------------------------------------
            7'b1100011: 
            begin
                imm_ext = {
                    {19{instr[31]}},
                    instr[31],
                    instr[7],
                    instr[30:25],
                    instr[11:8],
                    1'b0
                };
            end

            // ------------------------------------------
            // J-Type
            // JAL
            // ------------------------------------------
            7'b1101111: 
            begin
                imm_ext = {
                    {12{instr[31]}},
                    instr[19:12],
                    instr[20],
                    instr[30:21],
                    1'b0
                };
            end

            default: 
            begin
                imm_ext = 32'd0;
            end
        endcase
    end
endmodule

module program_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] pc_next,

    output reg  [31:0] pc
);

    always @(posedge clk or posedge reset)
     begin
        if (reset)
            pc <= 32'd0;

        else
            pc <= pc_next;
    end

endmodule

module instruction_memory (
    input  wire [31:0] pc,
    output wire [31:0] instr);

    // 256 words x 32 bits
    reg [31:0] rom [0:255];

    // PC is byte addressed.
    // Instructions are 4-byte aligned.
    // Therefore PC[9:2] gives the word index.
    wire [7:0] word_address;

    assign word_address = pc[9:2];

    // Asynchronous instruction read
    assign instr = rom[word_address];

endmodule

module data_memory (
    input  wire        clk,
    input  wire        MemWrite,
    input  wire        MemRead,

    input  wire [31:0] address,
    input  wire [31:0] write_data,

    output wire [31:0] read_data);

    // 256 words x 32 bits
    reg [31:0] ram [0:255];

    // Byte address -> word address
    wire [7:0] word_address;

    assign word_address = address[9:2];

    // ------------------------------------------
    // Asynchronous read
    // ------------------------------------------
    assign read_data =
        MemRead ? ram[word_address] : 32'd0;
    // ------------------------------------------
    // Synchronous write
    // ------------------------------------------

    always @(posedge clk)
    begin
        if (MemWrite)
            ram[word_address] <= write_data;
    end

    // ------------------------------------------
    // Initialize RAM for deterministic simulation
    // ------------------------------------------

    integer i;

    initial
    begin
        for (i = 0; i < 256; i = i + 1)
            ram[i] = 32'd0;
    end

endmodule

module control_unit (
    input  wire [6:0] opcode,

    output reg        RegWrite,
    output reg        ALUSrc,
    output reg        MemWrite,
    output reg        MemRead,
    output reg        MemtoReg,
    output reg        Branch,
    output reg        Jump,

    output reg [3:0]  ALUControl);

    always @(*) begin

        // ------------------------------------------
        // Safe defaults
        // ------------------------------------------

        RegWrite   = 1'b0;
        ALUSrc     = 1'b0;
        MemWrite   = 1'b0;
        MemRead    = 1'b0;
        MemtoReg   = 1'b0;
        Branch     = 1'b0;
        Jump       = 1'b0;

        ALUControl = 4'b0010;     // ADD

        case (opcode)

            // --------------------------------------
            // R-Type
            // --------------------------------------
            7'b0110011: 
            begin
                RegWrite   = 1'b1;
                ALUSrc     = 1'b0;
                MemtoReg   = 1'b0;
                ALUControl = 4'b0010;
            end

            // --------------------------------------
            // I-Type
            // ADDI
            // --------------------------------------
            7'b0010011:
            begin
                RegWrite   = 1'b1;
                ALUSrc     = 1'b1;
                MemtoReg   = 1'b0;
                ALUControl = 4'b0010;
            end

            // --------------------------------------
            // Load Word
            // LW
            // --------------------------------------
            7'b0000011: 
            begin
                RegWrite   = 1'b1;
                ALUSrc     = 1'b1;
                MemRead    = 1'b1;
                MemtoReg   = 1'b1;
                ALUControl = 4'b0010;
            end

            // --------------------------------------
            // Store Word
            // SW
            // --------------------------------------
            7'b0100011:
             begin
                RegWrite   = 1'b0;
                ALUSrc     = 1'b1;
                MemWrite   = 1'b1;
                ALUControl = 4'b0010;
            end

            // --------------------------------------
            // Branch Equal
            // BEQ
            // --------------------------------------
            7'b1100011:
             begin
                RegWrite   = 1'b0;
                ALUSrc     = 1'b0;
                Branch     = 1'b1;
                ALUControl = 4'b0110;
            end

            // --------------------------------------
            // Jump And Link
            // JAL
            // --------------------------------------
            7'b1101111:
             begin
                // JAL writes PC+4 to rd.
                // If rd=x0, register_file
                // automatically ignores the write.
                RegWrite   = 1'b1;

                ALUSrc     = 1'b0;
                MemtoReg   = 1'b0;
                Branch     = 1'b0;
                Jump       = 1'b1;

                ALUControl = 4'b0010;

            end

            default:
             begin
                // Keep safe defaults
            end

        endcase

    end

endmodule

module riscv_single_cycle (
    input wire clk,
    input wire reset
);

    // ==================================================
    // PC signals
    // ==================================================

    wire [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    wire [31:0] pc_target;

    // ==================================================
    // Instruction signals
    // ==================================================

    wire [31:0] instr;

    // ==================================================
    // Register / ALU signals
    // ==================================================

    wire [31:0] src_a;
    wire [31:0] src_b;

    wire [31:0] write_data;

    wire [31:0] alu_result;
    wire [31:0] read_data;

    wire [31:0] result_wb;

    wire [31:0] imm_ext;

    // ==================================================
    // Control signals
    // ==================================================

    wire        RegWrite;
    wire        ALUSrc;
    wire        MemWrite;
    wire        MemRead;
    wire        MemtoReg;
    wire        Branch;
    wire        Jump;

    wire        alu_zero;

    wire [3:0]  ALUControl;

    // ==================================================
    // PC calculation
    // ==================================================

    assign pc_plus4  = pc + 32'd4;

    assign pc_target = pc + imm_ext;

    assign pc_next =
        (Jump || (Branch && alu_zero))
        ? pc_target
        : pc_plus4;

    // ==================================================
    // Program Counter
    // ==================================================

    program_counter PC_Reg (
        .clk    (clk),
        .reset  (reset),
        .pc_next(pc_next),
        .pc     (pc)
    );

    // ==================================================
    // Instruction Memory
    // ==================================================

    instruction_memory Instr_Mem (
        .pc   (pc),
        .instr(instr)
    );

    // ==================================================
    // Control Unit
    // ==================================================

    control_unit Ctrl_Unit (
        .opcode    (instr[6:0]),

        .RegWrite  (RegWrite),
        .ALUSrc    (ALUSrc),
        .MemWrite  (MemWrite),
        .MemRead   (MemRead),
        .MemtoReg  (MemtoReg),
        .Branch    (Branch),
        .Jump      (Jump),

        .ALUControl(ALUControl)
    );

    // ==================================================
    // Register File
    // ==================================================

    register_file Reg_File (
        .clk       (clk),
        .reset     (reset),

        .RegWrite  (RegWrite),

        .A1        (instr[19:15]),
        .A2        (instr[24:20]),
        .A3        (instr[11:7]),

        .WD3       (result_wb),

        .RD1       (src_a),
        .RD2       (write_data)
    );

    // ==================================================
    // Immediate Generator
    // ==================================================

    imm_gen Immediate_Gen (
        .instr   (instr),
        .imm_ext (imm_ext)
    );

    // ==================================================
    // ALU source B multiplexer
    // ==================================================

    assign src_b =
        ALUSrc ? imm_ext : write_data;

    // ==================================================
    // ALU
    // ==================================================

    alu Core_ALU (
        .A         (src_a),
        .B         (src_b),

        .ALUControl(ALUControl),

        .Result    (alu_result),
        .Zero      (alu_zero)
    );

    // ==================================================
    // Data Memory
    // ==================================================

    data_memory Data_Mem (
        .clk       (clk),

        .MemWrite  (MemWrite),
        .MemRead   (MemRead),

        .address   (alu_result),
        .write_data(write_data),

        .read_data (read_data)
    );

    // ==================================================
    // Writeback MUX
    //
    // JAL  -> PC + 4
    // LW   -> Memory data
    // Other -> ALU result
    // ==================================================

    assign result_wb =
        Jump
        ? pc_plus4
        : (MemtoReg ? read_data : alu_result);

endmodule
