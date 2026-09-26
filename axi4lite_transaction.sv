// -----------------------------------------------------------------------------
// File        : axi4lite_transaction.sv
// Description : UVM sequence item representing a single AXI4-Lite
//               transaction (either a READ or a WRITE). Also used by the
//               monitor to publish observed AW/W/B or AR/R activity to the
//               scoreboard and coverage collector.
// -----------------------------------------------------------------------------

class axi4lite_transaction extends uvm_sequence_item;

    typedef enum bit { AXI_WRITE = 1'b0, AXI_READ = 1'b1 } axi_dir_e;

    // ------------------------------------------------------------------
    // Randomizable transaction fields
    // ------------------------------------------------------------------
    rand axi_dir_e            dir;
    rand bit [31:0]           addr;
    rand bit [31:0]           wdata;
    rand bit [3:0]            wstrb;

    // Independent-arrival control (write only): how many cycles to delay
    // asserting AWVALID / WVALID relative to the start of the transaction.
    // 0 = assert immediately / together.
    rand int unsigned         aw_delay;
    rand int unsigned         w_delay;

    // Backpressure control: number of cycles the driver should keep the
    // "downstream" ready signal deasserted before accepting/consuming.
    rand int unsigned         bready_delay;  // write response backpressure
    rand int unsigned         rready_delay;  // read data backpressure
    rand int unsigned         awready_stall; // (monitor/DUT side, informational)
    rand int unsigned         arready_stall; // (monitor/DUT side, informational)

    // ------------------------------------------------------------------
    // Observed / response fields (filled in by driver after the
    // handshake completes, or by the monitor when snooping the bus)
    // ------------------------------------------------------------------
    bit [31:0]  rdata;
    bit [1:0]   bresp;
    bit [1:0]   rresp;
    time        start_time;
    time        end_time;

    `uvm_object_utils_begin(axi4lite_transaction)
        `uvm_field_enum(axi_dir_e, dir,   UVM_ALL_ON)
        `uvm_field_int(addr,               UVM_ALL_ON)
        `uvm_field_int(wdata,              UVM_ALL_ON)
        `uvm_field_int(wstrb,              UVM_ALL_ON)
        `uvm_field_int(aw_delay,           UVM_ALL_ON)
        `uvm_field_int(w_delay,            UVM_ALL_ON)
        `uvm_field_int(bready_delay,       UVM_ALL_ON)
        `uvm_field_int(rready_delay,       UVM_ALL_ON)
        `uvm_field_int(rdata,              UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(bresp,              UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(rresp,              UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_object_utils_end

    function new(string name = "axi4lite_transaction");
        super.new(name);
    endfunction

    // ------------------------------------------------------------------
    // Constraints
    // ------------------------------------------------------------------

    // Default: word-aligned addresses within the implemented register
    // window most of the time, with a small chance of an out-of-range
    // or unaligned address to exercise SLVERR paths during random
    // regression. axi4lite_pkg::NUM_REGS is visible via the RTL package
    // import at the testbench package level.
    constraint c_addr_reasonable {
        addr[1:0] == 2'b00;
        addr inside {[0 : (axi4lite_pkg::NUM_REGS*4) - 4]};
    }

    constraint c_wstrb_nonzero {
        wstrb != 4'h0;
    }

    constraint c_delays_small {
        aw_delay      inside {[0:4]};
        w_delay       inside {[0:4]};
        bready_delay  inside {[0:4]};
        rready_delay  inside {[0:4]};
    }

    // ------------------------------------------------------------------
    // Convenience factory-style creators used by directed sequences
    // ------------------------------------------------------------------
    static function axi4lite_transaction create_write(
        bit [31:0] addr, bit [31:0] data, bit [3:0] strb = 4'hF,
        int unsigned aw_delay = 0, int unsigned w_delay = 0
    );
        axi4lite_transaction t = axi4lite_transaction::type_id::create("wr_txn");
        t.dir      = AXI_WRITE;
        t.addr     = addr;
        t.wdata    = data;
        t.wstrb    = strb;
        t.aw_delay = aw_delay;
        t.w_delay  = w_delay;
        return t;
    endfunction

    static function axi4lite_transaction create_read(bit [31:0] addr);
        axi4lite_transaction t = axi4lite_transaction::type_id::create("rd_txn");
        t.dir  = AXI_READ;
        t.addr = addr;
        return t;
    endfunction

    function string convert2string();
        if (dir == AXI_WRITE)
            return $sformatf("WRITE addr=0x%08h data=0x%08h strb=%04b aw_delay=%0d w_delay=%0d bresp=%0d",
                              addr, wdata, wstrb, aw_delay, w_delay, bresp);
        else
            return $sformatf("READ  addr=0x%08h rdata=0x%08h rresp=%0d", addr, rdata, rresp);
    endfunction

endclass : axi4lite_transaction
