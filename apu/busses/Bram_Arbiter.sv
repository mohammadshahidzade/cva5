module Bram_Arbiter
    #(
        parameter int unsigned NUM_MASTERS = 1
    ) (
        input clk,
        local_memory_interface masters[NUM_MASTERS-1:0],
        local_memory_interface  slave
    );


    // ila_3 ila (
    //     .clk(clk), 
    //     .probe1(en_vec), 
    //     .probe2(slave_sel)
    //     .probe3(be_vec[slave_sel]), 
    //     .probe4(data_in_vec[slave_sel]), 
    //     .probe5(data_out_vec[slave_sel])
    // );

    logic[29:0] addr_vec[NUM_MASTERS-1:0];
    logic[NUM_MASTERS-1:0] en_vec;
    logic[3:0] be_vec[NUM_MASTERS-1:0];
    logic[31:0] data_in_vec[NUM_MASTERS-1:0];
    logic[31:0] data_out_vec[NUM_MASTERS-1:0];
    logic[$clog2(NUM_MASTERS)-1:0] slave_sel;

    generate for (genvar i = 0; i < NUM_MASTERS; i++) begin : gen_connections
        assign addr_vec[i] = masters[i].addr;
        assign en_vec[i] = masters[i].en;
        assign be_vec[i] = masters[i].be;
        assign data_in_vec[i] = masters[i].data_in;
        assign masters[i].data_out = data_out_vec[i];
    end endgenerate


    one_hot_to_integer #(.C_WIDTH(NUM_MASTERS)) onehot (
        .one_hot(en_vec),
        .int_out(slave_sel)
    );

    //Slave connections
    assign slave.addr = addr_vec[slave_sel];
    assign slave.en = en_vec[slave_sel];
    assign slave.be = be_vec[slave_sel];
    assign slave.data_in = data_in_vec[slave_sel];
    // assign data_out_vec[slave_sel] = slave.data_out;
    always_comb begin
        for (int i = 0; i < NUM_MASTERS; i++) begin
            data_out_vec[i] = slave.data_out;
        end
    end

endmodule
