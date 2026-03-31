module accelerator_invalidation (
    input  logic        clk,
    input  logic        rst_n,
    
    // 3 Input Packets
    input  logic [2:0]  vld_in,
    input  logic [2:0]  rdy_in,
    input  logic [31:0] addr_in [3],
    input  logic [7:0] len_in  [3],
    
    // Non-cachable boundaries from your config
    input  logic [31:0] NON_CACHABLE_L,
    input  logic [31:0] NON_CACHABLE_H,
    
    // Outputs
    output logic [31:0] inv_addr_out,
    output logic        hold_out
);
    // Cache Parameters
    // If LINE_W is 8, it usually implies a 256-bit line (32 bytes)
    localparam int LINE_SIZE_BYTES = 32; 

    // Internal State
    logic [31:0] next_addr [3];
    logic [9:0] remaining [3];
    logic [1:0]  rr_ptr;

    // Helper Function: Check if address is CACHABLE
    // It is cachable if it is NOT within the Non-Cachable range
    function automatic logic is_cachable(logic [31:0] addr);
        return (addr < NON_CACHABLE_L || addr > NON_CACHABLE_H);
    endfunction

    // Combinational Logic: Compute next address by zeroing bits [4:0] and incrementing bit 5
    logic [31:0] next_addr_computed [3];
    logic [31:0] moved_amount [3];
    always_comb begin
        for (int i = 0; i < 3; i++) begin
            // The word-address of the very first word in the NEXT cache line
            // We take the current line index [31:5], add 1, then the word-offset is 000
            logic [29:0] current_word_addr;
            logic [29:0] next_line_word_addr;

            current_word_addr   = next_addr[i][31:2];
            next_line_word_addr = {next_addr[i][31:5] + 1'b1, 3'b000}; 

            next_addr_computed[i] = {next_line_word_addr, 2'b00}; // Back to byte address
            moved_amount[i]       = next_line_word_addr - current_word_addr;
        end
    end

    // 1. Input Capture & State Update Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 3; i++) begin
                next_addr[i] <= 32'h0;
                remaining[i] <= 10'h0;
            end
        end else begin
            for (int i = 0; i < 3; i++) begin
                if (vld_in[i] && rdy_in[i]) begin
                    // Initial capture: Align address to cache line start if necessary
                    if({remaining[i],2'b00}+next_addr[i] == addr_in[i]-2'h20) begin
                        next_addr[i] <= next_addr[i]; // Hold current address if we're still processing 
                        remaining[i] <= remaining[i] + {len_in[i], 1'b0}+2'b10;
                    end else begin
                        next_addr[i] <= addr_in[i];
                        remaining[i] <= {len_in[i], 1'b0}+2'b10;
                        // next_addr[i] <= { addr_in[i][31:5] + 1'b1, 5'b0 };
                        // remaining[i] <= ({len_in[i], 1'b0} + 2'b10) ? ({len_in[i], 1'b0} + 2'b10) - 1 : 0;
                    end 
                end 
                // Only update if this stream is chosen AND it's valid/cachable
                else if (rr_ptr == i && remaining[i] > 0 && is_cachable(next_addr[i])) begin
                    next_addr[i] <= next_addr_computed[i]; // Jump to next cache line
                    // Ensure remaining doesn't underflow
                    remaining[i] <= (remaining[i] > moved_amount[i]) ? 
                                    (remaining[i] - moved_amount[i]) : 0;
                end
            end
        end
    end

    // 2. Round Robin Arbitration
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_ptr       <= 0;
            inv_addr_out <= 32'h0;
            hold_out     <= 1'b0;
        end else begin
            // Pointer rotates every cycle regardless of validity to maintain fairness
            rr_ptr <= (rr_ptr >= 2) ? 0 : rr_ptr + 1;

            // Output logic: Check current pointer's stream
            if (remaining[rr_ptr] > 0 && is_cachable(next_addr[rr_ptr])) begin
                inv_addr_out <= next_addr[rr_ptr];
                hold_out     <= 1'b1;
            end else begin
                hold_out     <= 1'b0;
                inv_addr_out <= 32'h0;
            end
        end
    end

endmodule