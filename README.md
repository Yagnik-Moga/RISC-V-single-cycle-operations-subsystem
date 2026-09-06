# RISC-V-single-cycle-operations-subsystem
1. ARCHITECTURE OVERVIEW
The processor core operates on a classic single-cycle scheme where every instruction completes its entire fetch-decode-execute loop within exactly one clock cycle. The design is partitioned into modular, highly readable submodules cleanly tied together inside a top-level hardware wrapper.
    • Instruction Fetch (IF): The Program Counter (PC) holds the current execution address. It continuously points to the Instruction Memory, which instantly decodes the address to fetch a 32-bit instruction word.
    • Instruction Decode & Control (ID): The fetched instruction is split into pieces. The lower bits (Opcode) go to the Control Unit, which acts as the brain of the processor, turning on control switches like write enables and multiplexer selectors. Concurrently, the Immediate Generator extracts scrambled bits from the instruction and formats them into a clean, 32-bit signed immediate value.
    • Operand Access: The instruction also specifies source register addresses. The Register File reads these addresses asynchronously, instantly outputting the stored values of registers x0 through x31.
    • Execution (EX): The core ALU performs mathematical or logical operations. It takes its first input from the register file. Its second input is chosen dynamically via a multiplexer, which switches between the second register value (for register-to-register math) or the sign-extended immediate value (for load/store and immediate math).
    • Memory Access (MEM): For memory operations, the ALU result serves as a address pointer. The Data Memory reads data out asynchronously or stores a register value synchronously on the next clock edge.
    • Writeback (WB): Finally, a multi-way Writeback Multiplexer chooses what data should be saved back into the register file destination. It selects either the raw ALU calculation, the data retrieved from memory, or a return pointer (PC + 4) used during jump operations.
2. SUPPORTED INSTRUCTION TYPES
The system decodes targeted operation types exclusively by inspecting the unique incoming instruction opcodes (instr[6:0]):
    • R-Type (Opcode: 7'b0110011): Covers register-to-register functions (ADD, SUB, AND, OR, SLT, NOR).
    • I-Type (Opcode: 7'b0010011): Implements register-immediate calculations (ADDI).
    • Load Word (Opcode: 7'b0000011): Loads a 32-bit word directly from RAM into the register file (LW).
    • Store Word (Opcode: 7'b0100011): Saves a 32-bit word from registers down into RAM (SW).
    • Branch Equal (Opcode: 7'b1100011): Conducts PC-relative structural branching if contents are identical (BEQ).
    • Jump and Link (Opcode: 7'b1101111): Completes an unconditional PC-relative code jump (JAL) while tracking runtime returns.

3. CORE SUBMODULE BREAKDOWN
riscv_single_cycle (Top-Level Wrapper)
Binds the entire design fabric together. It manages interconnect wiring, handles PC updates (branch/jump target multiplexing), selects ALU operand B sources, and drives the write-back routing destination.
program_counter
A 32-bit pointer register driving active execution tracking. It responds to an active-high reset signal which unconditionally forces the PC back to base reference position 32'd0.
instruction_memory
A 256-word × 32-bit asynchronous ROM housing structural software data. It utilizes drop-down word index parsing extracted dynamically from standard byte addresses (pc[9:2]).
control_unit
The centralized combinational master decoder matrix. It parses structural opcode segments and maps runtime signal properties across the system execution layout:
    • RegWrite: Enables writing back to the Register File.
    • ALUSrc: Toggles ALU Input B source (Register File vs. Sign-Extended Immediate).
    • MemRead / MemWrite: Flags operational memory pipeline routines.
    • MemtoReg: Switches structural Writeback Multiplexer inputs (ALU vs. Data Memory).
    • Branch / Jump: Flags valid evaluation updates over the default incremental program flow.
    • ALUControl: Outputs definitive functional math operation commands to the core ALU.
register_file
A dual-port architecture structure containing 32 independent general-purpose 32-bit register rows (x0 through x31).
    • Dual Asynchronous Reads: Provides immediate data readout from ports A1 and A2.
    • Synchronous Updates: Writes back to destination port A3 on the rising clock edge when RegWrite is high.
    • Hardwired Zero Line: Standard register tracking block x0 remains hardwired to 32'd0 for both reads and writes.
imm_gen (Immediate Generator)
Extracts and un-scrambles complex, non-contiguous bit groups from incoming instruction lines. It transforms them into fully formed, sign-extended 32-bit values matching I, S, B, and J alignments.
alu (Arithmetic Logic Unit)
Executes core mathematical calculations based on a targeted 4-bit ALUControl mapping bus:
    • 4'b0000: Bitwise AND
    • 4'b0001: Bitwise OR
    • 4'b0010: Arithmetic ADD
    • 4'b0110: Arithmetic SUB
    • 4'b0111: Set Less Than (SLT) (Signed)
    • 4'b1100: Bitwise NOR
    • Zero Flag: Asserts a logic 1 on wire Zero whenever the mathematical result hits 32'b0.
data_memory
A volatile internal 256-word × 32-bit RAM workspace module.
    • Asynchronous Read: Outputs contents instantaneously whenever MemRead is active.
    • Synchronous Write: Locks in valid register data on the rising clock edge when MemWrite is high.
    • Initialization Block: Zeroes out the active memory space at startup during simulation loops.

4. ARCHITECTURAL CONSIDERATIONS
    • Word Alignment: To keep the footprint simple, instructions and data elements drop the lower two bits of byte-addressed pointers (address[9:2]), framing clear word-aligned lookups.
    • Single-Phase Branching: Conditional calculations run fully inside a single active phase cycle. When Branch and Zero match criteria simultaneously, the execution pipeline instantly redirects to PC + imm_ext instead of stepping forward to PC + 4.
    • Subroutine Support:
Unconditional jumps (JAL) pass return vectors (PC + 4) straight to the write-back stage to preserve programmatic context.

5. SIMULATION & VERIFICATION
   Use EDA Playground and open the given link to observe the simulation log and output waveforms.

Link - https://www.edaplayground.com/x/tPDS
