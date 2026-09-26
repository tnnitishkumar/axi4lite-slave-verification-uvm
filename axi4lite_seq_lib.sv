// -----------------------------------------------------------------------------
// File        : axi4lite_seq_lib.sv
// Description : Sequence library for the AXI4-Lite UVM environment: a base
//               sequence with common helpers, one directed sequence per
//               verification-plan scenario, and a constrained-random
//               sequence for regression.
// -----------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Base sequence: common single-transaction helpers used by every directed
// sequence below.
// ---------------------------------------------------------------------------
class axi4lite_base_seq extends uvm_sequence #(axi4lite_transaction);

    `uvm_object_utils(axi4lite_base_seq)

    function new(string name = "axi4lite_base_seq");
        super.new(name);
    endfunction

    task do_write(bit [31:0] addr, bit [31:0] data, bit [3:0] strb = 4'hF,
                   int unsigned aw_delay = 0, int unsigned w_delay = 0,
                   int unsigned bready_delay = 0);
        axi4lite_transaction t = axi4lite_transaction::type_id::create("t_wr");
        start_item(t);
        if (!t.randomize() with {
            dir          == axi4lite_transaction::AXI_WRITE;
            addr         == local::addr;
            wdata        == local::data;
            wstrb        == local::strb;
            aw_delay     == local::aw_delay;
            w_delay      == local::w_delay;
            bready_delay == local::bready_delay;
        }) `uvm_error("SEQ", "randomize failed for do_write")
        finish_item(t);
    endtask

    task do_read(bit [31:0] addr, int unsigned rready_delay = 0);
        axi4lite_transaction t = axi4lite_transaction::type_id::create("t_rd");
        start_item(t);
        if (!t.randomize() with {
            dir          == axi4lite_transaction::AXI_READ;
            addr         == local::addr;
            rready_delay == local::rready_delay;
        }) `uvm_error("SEQ", "randomize failed for do_read")
        finish_item(t);
    endtask

endclass : axi4lite_base_seq


// ---------------------------------------------------------------------------
// 1) Single write, single read-back
// ---------------------------------------------------------------------------
class axi4lite_single_rw_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_single_rw_seq)
    function new(string name = "axi4lite_single_rw_seq"); super.new(name); endfunction
    task body();
        do_write(32'h0000_0000, 32'hDEAD_BEEF);
        do_read (32'h0000_0000);
    endtask
endclass : axi4lite_single_rw_seq


// ---------------------------------------------------------------------------
// 2) Multiple sequential writes/reads across several registers
// ---------------------------------------------------------------------------
class axi4lite_multiple_rw_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_multiple_rw_seq)
    function new(string name = "axi4lite_multiple_rw_seq"); super.new(name); endfunction
    task body();
        for (int i = 0; i < axi4lite_pkg::NUM_REGS; i++) begin
            do_write(i*4, 32'hA000_0000 + i);
        end
        for (int i = 0; i < axi4lite_pkg::NUM_REGS; i++) begin
            do_read(i*4);
        end
    endtask
endclass : axi4lite_multiple_rw_seq


// ---------------------------------------------------------------------------
// 3) Back-to-back transactions with zero idle cycles between them (relies
//    on the sequencer/driver pipeline - items are issued immediately after
//    one another with no inserted delay)
// ---------------------------------------------------------------------------
class axi4lite_back_to_back_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_back_to_back_seq)
    function new(string name = "axi4lite_back_to_back_seq"); super.new(name); endfunction
    task body();
        do_write(32'h0000_0000, 32'h1111_1111, 4'hF, 0, 0, 0);
        do_write(32'h0000_0004, 32'h2222_2222, 4'hF, 0, 0, 0);
        do_write(32'h0000_0008, 32'h3333_3333, 4'hF, 0, 0, 0);
        do_read (32'h0000_0000, 0);
        do_read (32'h0000_0004, 0);
        do_read (32'h0000_0008, 0);
    endtask
endclass : axi4lite_back_to_back_seq


// ---------------------------------------------------------------------------
// 4) Independent AW/W arrival: AW first (W delayed), then W first (AW
//    delayed), exercising both orderings explicitly.
// ---------------------------------------------------------------------------
class axi4lite_independent_aw_w_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_independent_aw_w_seq)
    function new(string name = "axi4lite_independent_aw_w_seq"); super.new(name); endfunction
    task body();
        // AW arrives well before W
        do_write(32'h0000_000C, 32'hAAAA_0001, 4'hF, 0, 6);
        do_read (32'h0000_000C);
        // W arrives well before AW
        do_write(32'h0000_0010, 32'hAAAA_0002, 4'hF, 6, 0);
        do_read (32'h0000_0010);
        // Same cycle (both zero delay)
        do_write(32'h0000_0014, 32'hAAAA_0003, 4'hF, 0, 0);
        do_read (32'h0000_0014);
    endtask
endclass : axi4lite_independent_aw_w_seq


// ---------------------------------------------------------------------------
// 5) WSTRB partial-write coverage: exercise every single-byte and
//    half-word strobe pattern.
// ---------------------------------------------------------------------------
class axi4lite_wstrb_partial_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_wstrb_partial_seq)
    function new(string name = "axi4lite_wstrb_partial_seq"); super.new(name); endfunction
    task body();
        bit [3:0] patterns [8] = '{4'b0001, 4'b0010, 4'b0100, 4'b1000,
                                    4'b0011, 4'b1100, 4'b1010, 4'b1111};
        foreach (patterns[i]) begin
            do_write(32'h0000_0018, 32'h0000_0000, 4'hF); // clear first
            do_write(32'h0000_0018, 32'hFFFF_FFFF, patterns[i]);
            do_read (32'h0000_0018);
        end
    endtask
endclass : axi4lite_wstrb_partial_seq


// ---------------------------------------------------------------------------
// 6) Invalid / out-of-range and unaligned addresses -> expect SLVERR
// ---------------------------------------------------------------------------
class axi4lite_invalid_addr_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_invalid_addr_seq)
    function new(string name = "axi4lite_invalid_addr_seq"); super.new(name); endfunction
    task body();
        // Out of range (beyond NUM_REGS*4)
        do_write(32'hFFFF_FFF0, 32'hFFFF_FFFF);
        do_read (32'hFFFF_FFF0);
        do_write(32'h0000_1000, 32'hFFFF_FFFF);
        do_read (32'h0000_1000);
        // Unaligned
        do_write(32'h0000_0001, 32'hFFFF_FFFF);
        do_read (32'h0000_0002);
        do_write(32'h0000_0003, 32'hFFFF_FFFF);
    endtask
endclass : axi4lite_invalid_addr_seq


// ---------------------------------------------------------------------------
// 7) BREADY backpressure: delay the write-response ready by several
//    cycles to exercise BVALID stability and the slave stalling.
// ---------------------------------------------------------------------------
class axi4lite_bready_backpressure_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_bready_backpressure_seq)
    function new(string name = "axi4lite_bready_backpressure_seq"); super.new(name); endfunction
    task body();
        do_write(32'h0000_001C, 32'h5555_5555, 4'hF, 0, 0, 5);
        do_write(32'h0000_001C, 32'h6666_6666, 4'hF, 0, 0, 10);
        do_read (32'h0000_001C);
    endtask
endclass : axi4lite_bready_backpressure_seq


// ---------------------------------------------------------------------------
// 8) RREADY backpressure: delay read-data ready to exercise RVALID
//    stability while the master stalls consumption.
// ---------------------------------------------------------------------------
class axi4lite_rready_backpressure_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_rready_backpressure_seq)
    function new(string name = "axi4lite_rready_backpressure_seq"); super.new(name); endfunction
    task body();
        do_write(32'h0000_0020, 32'h7777_7777);
        do_read (32'h0000_0020, 5);
        do_read (32'h0000_0020, 10);
    endtask
endclass : axi4lite_rready_backpressure_seq


// ---------------------------------------------------------------------------
// 9) AWREADY/WREADY/ARREADY-side "backpressure": from the master's
//    perspective this is driven implicitly since the DUT itself withholds
//    these readies while a previous address is still pending commit; this
//    sequence issues writes/reads immediately back-to-back (zero gap) so
//    the driver's do..while(!READY) loops are forced to stall for several
//    cycles, exercising that path explicitly.
// ---------------------------------------------------------------------------
class axi4lite_slave_stall_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_slave_stall_seq)
    function new(string name = "axi4lite_slave_stall_seq"); super.new(name); endfunction
    task body();
        // Issue a write with BREADY held off for a long time, then
        // immediately issue another - the second write's AWVALID will be
        // asserted while the slave is still busy with the first (since
        // the driver processes items sequentially through the sequencer),
        // and separately verify a subsequent read has to wait its turn.
        do_write(32'h0000_0024, 32'h1000_0001, 4'hF, 0, 0, 8);
        do_write(32'h0000_0024, 32'h1000_0002, 4'hF, 0, 0, 0);
        do_read (32'h0000_0024);
    endtask
endclass : axi4lite_slave_stall_seq


// ---------------------------------------------------------------------------
// 10) Constrained-random sequence for regression: random mix of reads and
//     writes, random addresses (including occasional invalid ones),
//     random WSTRB, random independent-arrival delays, random
//     backpressure.
// ---------------------------------------------------------------------------
class axi4lite_random_seq extends uvm_sequence #(axi4lite_transaction);

    `uvm_object_utils(axi4lite_random_seq)

    rand int unsigned num_txns = 50;
    constraint c_num_txns { num_txns inside {[20:200]}; }

    function new(string name = "axi4lite_random_seq");
        super.new(name);
    endfunction

    task body();
        repeat (num_txns) begin
            axi4lite_transaction t = axi4lite_transaction::type_id::create("t_rand");
            start_item(t);
            if (!t.randomize())
                `uvm_error("SEQ", "randomize failed in axi4lite_random_seq")
            finish_item(t);
        end
    endtask

endclass : axi4lite_random_seq


// ---------------------------------------------------------------------------
// 11) Corner-case sequence: min/max address, all-zero and all-one data,
//     zero-delay and max-delay backpressure combined.
// ---------------------------------------------------------------------------
class axi4lite_corner_case_seq extends axi4lite_base_seq;
    `uvm_object_utils(axi4lite_corner_case_seq)
    function new(string name = "axi4lite_corner_case_seq"); super.new(name); endfunction
    task body();
        // First and last valid register
        do_write(32'h0000_0000, 32'h0000_0000, 4'hF);
        do_write((axi4lite_pkg::NUM_REGS-1)*4, 32'hFFFF_FFFF, 4'hF);
        do_read (32'h0000_0000);
        do_read ((axi4lite_pkg::NUM_REGS-1)*4);
        // One-past-the-end (first invalid address)
        do_write(axi4lite_pkg::NUM_REGS*4, 32'hDEAD_DEAD, 4'hF);
        do_read (axi4lite_pkg::NUM_REGS*4);
        // Max independent-arrival skew combined with max backpressure
        do_write(32'h0000_0004, 32'hC0FF_EE00, 4'hF, 8, 0, 8);
        do_read (32'h0000_0004, 8);
        // Zero WSTRB-equivalent (single byte only) at boundary address
        do_write((axi4lite_pkg::NUM_REGS-1)*4, 32'h000000AB, 4'b0001);
        do_read ((axi4lite_pkg::NUM_REGS-1)*4);
    endtask
endclass : axi4lite_corner_case_seq
