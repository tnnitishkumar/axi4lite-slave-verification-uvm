// -----------------------------------------------------------------------------
// File        : axi4lite_sequencer.sv
// Description : Sequencer type for axi4lite_transaction.
// -----------------------------------------------------------------------------

class axi4lite_sequencer extends uvm_sequencer #(axi4lite_transaction);

    `uvm_component_utils(axi4lite_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : axi4lite_sequencer
