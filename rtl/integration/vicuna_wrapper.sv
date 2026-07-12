// Author: Sanit Parashar
// Original work -- no upstream equivalent
// License: MIT License (see LICENSE)

//
//  Project: vicuna_wrapper.sv
//  Description: Vicuna Coprocessor Wrapper (Final Master Version)
//

import my_pkg::*;

module vicuna_wrapper (
    input  logic        clk,
    input  logic        reset,
    input  logic        vector_req_E,   
    input  logic [31:0] instruction_E,  
    input  logic [31:0] rs1_data_E,     
    input  logic [31:0] rs2_data_E,     
    output logic        vicuna_busy, 
   
    // MEMORY BUS
    output logic        v_mem_valid,
    output logic        v_mem_we,
    output logic [3:0]  v_mem_be,
    output logic [31:0] v_mem_addr,
    output logic [31:0] v_mem_wdata,
    input  logic        v_mem_ready,
    input  logic        v_mem_result_valid, // Ignored internally
    input  logic [31:0] v_mem_rdata,

    // PENDING SIGNALS FOR THE ARBITER
    output logic        v_pending_load,
    output logic        v_pending_store, 

    output logic        v_xreg_we,     // XIF result write enable
    output logic [4:0]  v_xreg_rd,     // XIF result destination register
    output logic [31:0] v_xreg_data    // XIF result write data
);

    logic rst_ni;
    assign rst_ni = ~reset;

    vproc_xif #(
        .X_ID_WIDTH(1),
        .X_MEM_WIDTH(32)
    ) xif ();

    logic [31:0] debug_vtype;
    logic [31:0] debug_vl;

    // THE 4-STATE MACHINE
    typedef enum logic [1:0] {
        ST_IDLE        = 2'b00,
        ST_ISSUE       = 2'b01,
        ST_WAIT_RESULT = 2'b10,
        ST_RETIRE      = 2'b11  
    } state_t;

    state_t state, next_state;

    // REGISTERED COMMIT
    logic commit_valid_q;
    logic [0:0] commit_id_q;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state          <= ST_IDLE;
            commit_valid_q <= 1'b0;
            commit_id_q    <= '0;
        end else begin
            state          <= next_state;
            commit_valid_q <= xif.issue_valid && xif.issue_ready && xif.issue_resp.accept;
            commit_id_q    <= xif.issue_req.id;
        end
    end

    logic [31:0] smart_rs1;
    logic [31:0] smart_rs2;
    logic [2:0]  v_funct3;
    logic [4:0]  v_rs1;

    always_comb begin
        v_funct3 = instruction_E[14:12];
        v_rs1    = instruction_E[19:15];
        
        smart_rs1 = $isunknown(rs1_data_E) ? 32'b0 : rs1_data_E;
        smart_rs2 = $isunknown(rs2_data_E) ? 32'b0 : rs2_data_E;

        if (v_rs1 == 5'b0) smart_rs1 = 32'b0;
        else if (v_funct3 == 3'b011) smart_rs1 = {{27{instruction_E[19]}}, instruction_E[19:15]};
        else if (v_funct3 == 3'b111) smart_rs1 = {27'b0, instruction_E[19:15]};
        
        xif.issue_valid  = 1'b0;
        xif.result_ready = 1'b0;
        xif.issue_req.id    = '0; 
        xif.issue_req.instr = instruction_E;
        xif.issue_req.rs[0] = smart_rs1; 
        xif.issue_req.rs[1] = smart_rs2;
        xif.issue_req.rs_valid = 2'b11;
        
        xif.commit_valid       = commit_valid_q;
        xif.commit.id          = commit_id_q;
        xif.commit.commit_kill = 1'b0;

        // ==========================================
        // FIXED: X-SAFE & SLIPPAGE-PROOF STALL LOGIC
        // ==========================================
        vicuna_busy = (state != ST_IDLE) || (vector_req_E === 1'b1);
        if (state == ST_RETIRE) vicuna_busy = 1'b0; 

        next_state = state;

        case (state)
            ST_IDLE: begin
                if (vector_req_E === 1'b1) begin
                    xif.issue_valid = 1'b1;
                    if (xif.issue_ready) begin
                        if (xif.issue_resp.accept) next_state = ST_WAIT_RESULT;
                        else next_state = ST_RETIRE; 
                    end else begin
                        vicuna_busy = 1'b1; 
                        next_state = ST_ISSUE;
                    end
                end
            end
            ST_ISSUE: begin
                xif.issue_valid = 1'b1;
                if (xif.issue_ready) begin
                    if (xif.issue_resp.accept) next_state = ST_WAIT_RESULT;
                    else next_state = ST_RETIRE;
                end
            end
            ST_WAIT_RESULT: begin
                xif.result_ready = 1'b1;
                if (xif.result_valid) next_state = ST_RETIRE;
            end
            ST_RETIRE: begin
                next_state = ST_IDLE;
            end
            default: next_state = ST_IDLE;
        endcase
    end

    

    // ==========================================
    // THE 1-CYCLE PIPELINE FIX
    // ==========================================
    logic [0:0]  mem_id_q;
    logic        mem_valid_q;
    logic [31:0] mem_rdata_q;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_valid_q <= 1'b0;
            mem_id_q    <= '0;
            mem_rdata_q <= '0;
        end else begin
            // Drive the result valid signal one cycle later to satisfy Vicuna
            mem_valid_q <= xif.mem_valid;

            // CRITICAL FIX: Capture the combinational data EXACTLY when requested,
            // before the Arbiter steals the address bus back next cycle.
            if (xif.mem_valid) begin
                mem_rdata_q <= v_mem_rdata;
                mem_id_q    <= xif.mem_req.id;
            end
        end
    end

    // RESTORED: Drive memory bus to arbiter
    assign v_mem_valid = xif.mem_valid;
    assign v_mem_we    = xif.mem_req.we;
    assign v_mem_be    = xif.mem_req.be;
    assign v_mem_addr  = xif.mem_req.addr;
    assign v_mem_wdata = xif.mem_req.wdata[31:0]; 

    // Override the Ready signal so Vicuna can burst read
    assign xif.mem_ready = 1'b1;
    
    // RESTORED: Drive mem_resp back to Vicuna to prevent X-propagation stalls
    assign xif.mem_resp.exc     = 1'b0;
    assign xif.mem_resp.exccode = 6'b0;
    assign xif.mem_resp.dbg     = 1'b0;

    assign xif.mem_result_valid = mem_valid_q; 
    assign xif.mem_result.rdata = mem_rdata_q;   
    assign xif.mem_result.err   = 1'b0;
    assign xif.mem_result.id    = mem_id_q;

    assign v_xreg_we   = xif.result_valid & xif.result_ready & xif.result.we;
    assign v_xreg_rd   = xif.result.rd;
    assign v_xreg_data = xif.result.data[31:0];

    vproc_core #(
        .XIF_ID_W(1),
        .XIF_MEM_W(32),
        .DONT_CARE_ZERO(1) 
    ) u_vicuna (
        .clk_i         (clk),
        .rst_ni        (rst_ni),
        .xif_issue_if  (xif.coproc_issue),
        .xif_commit_if (xif.coproc_commit),
        .xif_mem_if    (xif.coproc_mem),
        .xif_memres_if (xif.coproc_mem_result),
        .xif_result_if (xif.coproc_result),
        
        .pending_load_o  (v_pending_load),
        .pending_store_o (v_pending_store),
        
        .csr_vtype_o   (debug_vtype),
        .csr_vl_o      (debug_vl),
        .csr_vstart_o  (),
        .csr_vstart_i  ('0),
        .csr_vstart_set_i (1'b0),
        .csr_vxrm_i    ('0),
        .csr_vxrm_set_i(1'b0),
        .csr_vxsat_i   (1'b0),
        .csr_vxsat_set_i(1'b0)
    );

    // DIAGNOSTIC SNOOPER
    always_ff @(posedge clk) begin
        if (xif.issue_valid && xif.issue_ready) begin
            $display("-------------------------------------------------------");
            $display("[VICUNA ISSUE]  Time: %0t ns | Instr: %h | VL: %0d", $time, xif.issue_req.instr, debug_vl);
        end
        if (v_mem_valid && v_mem_ready) begin 
            $display("[VICUNA MEMORY] Time: %0t ns | %s @ Addr: %h", $time, v_mem_we ? "WRITE" : "READ", v_mem_addr);
        end
        if (xif.result_valid && xif.result_ready) begin
            $display("[VICUNA RETIRE] Time: %0t ns | Instruction ID %0d complete", $time, xif.result.id);
        end
        for (int i=0; i<2; i++) begin
            if (u_vicuna.vregfile_wr_en_q[i]) begin
                $display("=======================================================");
                $display("[VICUNA VAULT]  Time: %0t ns | Port %0d Wrote to v%0d", $time, i, u_vicuna.vregfile_wr_addr_q[i]);
                $display("                Payload: %x", u_vicuna.vregfile_wr_data_q[i]);
                $display("=======================================================");
            end
        end
    end

endmodule