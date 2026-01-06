module Axi_Arbiter
    #(
        parameter int unsigned NUM_MASTERS = 1
    ) (
        input  logic clk,
        input  logic rst,

        axi_interface.master masters[NUM_MASTERS-1:0],
        axi_interface.slave  slave
    );

    // Guard against $clog2(1) == 0 width
    localparam int IDX_WIDTH = (NUM_MASTERS > 1) ? $clog2(NUM_MASTERS) : 1;

    // Arbitration request / grant signals
    logic [NUM_MASTERS-1:0] read_request;
    logic [NUM_MASTERS-1:0] write_request;
    logic [IDX_WIDTH-1:0]   read_grant_index;
    logic [IDX_WIDTH-1:0]   write_grant_index;
    logic                   read_grant_valid;
    logic                   write_grant_valid;

    // --- derive field widths from the slave interface so flats match exactly ---
    localparam int ARADDR_W  = $bits(slave.araddr);
    localparam int ARLEN_W   = $bits(slave.arlen);
    localparam int ARSIZE_W  = $bits(slave.arsize);
    localparam int ARBURST_W = $bits(slave.arburst);
    localparam int ARCACHE_W = $bits(slave.arcache);
    localparam int ARLOCK_W  = $bits(slave.arlock);
    localparam int ARID_W    = $bits(slave.arid);

    localparam int AWADDR_W  = $bits(slave.awaddr);
    localparam int AWLEN_W   = $bits(slave.awlen);
    localparam int AWSIZE_W  = $bits(slave.awsize);
    localparam int AWBURST_W = $bits(slave.awburst);
    localparam int AWCACHE_W = $bits(slave.awcache);
    localparam int AWLOCK_W  = $bits(slave.awlock);
    localparam int AWID_W    = $bits(slave.awid);

    localparam int WDATA_W   = $bits(slave.wdata);
    localparam int WSTRB_W   = $bits(slave.wstrb);

    localparam int BID_W     = $bits(masters[0].bid); // b channel id width (use master's side)
    localparam int BRESP_W   = $bits(masters[0].bresp);

    // --- flattened arrays (per-master copies of interface fields) ---
    logic [NUM_MASTERS-1:0]                          arvalid_flat;
    logic [NUM_MASTERS-1:0][ARADDR_W-1:0]           araddr_flat;
    logic [NUM_MASTERS-1:0][ARLEN_W-1:0]            arlen_flat;
    logic [NUM_MASTERS-1:0][ARSIZE_W-1:0]           arsize_flat;
    logic [NUM_MASTERS-1:0][ARBURST_W-1:0]          arburst_flat;
    logic [NUM_MASTERS-1:0][ARCACHE_W-1:0]          arcache_flat;
    logic [NUM_MASTERS-1:0][ARLOCK_W-1:0]           arlock_flat;
    logic [NUM_MASTERS-1:0][ARID_W-1:0]             arid_flat;

    logic [NUM_MASTERS-1:0]                          awvalid_flat;
    logic [NUM_MASTERS-1:0][AWADDR_W-1:0]           awaddr_flat;
    logic [NUM_MASTERS-1:0][AWLEN_W-1:0]            awlen_flat;
    logic [NUM_MASTERS-1:0][AWSIZE_W-1:0]           awsize_flat;
    logic [NUM_MASTERS-1:0][AWBURST_W-1:0]          awburst_flat;
    logic [NUM_MASTERS-1:0][AWCACHE_W-1:0]          awcache_flat;
    logic [NUM_MASTERS-1:0][AWLOCK_W-1:0]           awlock_flat;
    logic [NUM_MASTERS-1:0][AWID_W-1:0]             awid_flat;

    logic [NUM_MASTERS-1:0]                          wvalid_flat;
    logic [NUM_MASTERS-1:0][WDATA_W-1:0]            wdata_flat;
    logic [NUM_MASTERS-1:0][WSTRB_W-1:0]            wstrb_flat;
    logic [NUM_MASTERS-1:0]                          wlast_flat;

    // b-channel outputs per master (to drive masters)
    logic [NUM_MASTERS-1:0]                          bvalid_flat;
    logic [NUM_MASTERS-1:0][BRESP_W-1:0]            bresp_flat;
    logic [NUM_MASTERS-1:0][BID_W-1:0]              bid_flat;

    // ack / ready outputs to masters (driven back) - single driver inside always_comb
    logic [NUM_MASTERS-1:0] arready_flat;
    logic [NUM_MASTERS-1:0] awready_flat;
    logic [NUM_MASTERS-1:0] wready_flat;

    genvar i;
    // Build requests and populate flattened arrays from interface masters
    generate
        for (i = 0; i < NUM_MASTERS; i = i + 1) begin : FLATTEN
            // request signals
            assign read_request[i]  = masters[i].arvalid & ~masters[i].arready;
            assign write_request[i] = masters[i].awvalid & ~masters[i].awready;

            // copy master's outputs into flat arrays
            assign arvalid_flat[i]   = masters[i].arvalid;
            assign araddr_flat[i]    = masters[i].araddr;
            assign arlen_flat[i]     = masters[i].arlen;
            assign arsize_flat[i]    = masters[i].arsize;
            assign arburst_flat[i]   = masters[i].arburst;
            assign arcache_flat[i]   = masters[i].arcache;
            assign arlock_flat[i]    = masters[i].arlock;
            assign arid_flat[i]      = masters[i].arid;

            assign awvalid_flat[i]   = masters[i].awvalid;
            assign awaddr_flat[i]    = masters[i].awaddr;
            assign awlen_flat[i]     = masters[i].awlen;
            assign awsize_flat[i]    = masters[i].awsize;
            assign awburst_flat[i]   = masters[i].awburst;
            assign awcache_flat[i]   = masters[i].awcache;
            assign awlock_flat[i]    = masters[i].awlock;
            assign awid_flat[i]      = masters[i].awid;

            assign wvalid_flat[i]    = masters[i].wvalid;
            assign wdata_flat[i]     = masters[i].wdata;
            assign wstrb_flat[i]     = masters[i].wstrb;
            assign wlast_flat[i]     = masters[i].wlast;

            // drive back ready/ack signals from flats (these are single continuous assignments
            // driven by the arbiter's always_comb via the arready_flat/awready_flat/wready_flat vectors)
            assign masters[i].arready = arready_flat[i];
            assign masters[i].awready = awready_flat[i];
            assign masters[i].wready  = wready_flat[i];

            // b-channel outputs to masters
            assign masters[i].bvalid = bvalid_flat[i];
            assign masters[i].bresp  = bresp_flat[i];
            assign masters[i].bid    = bid_flat[i];
        end
    endgenerate

    // Round-robin arbiters
    round_robin #(.NUM_PORTS(NUM_MASTERS)) read_arbiter (
        .requests(read_request),
        .grant(read_grant_index),
        .grantee(read_grant_valid),
        .*
    );

    round_robin #(.NUM_PORTS(NUM_MASTERS)) write_arbiter (
        .requests(write_request),
        .grant(write_grant_index),
        .grantee(write_grant_valid),
        .*
    );

    // --- Read channel: mux flattened arrays into slave (combinational) ---
    always_comb begin
        // defaults for slave read-side driven signals (arbiter -> slave)
        slave.arvalid = 1'b0;
        slave.araddr  = '0;
        slave.arlen   = '0;
        slave.arsize  = '0;
        slave.arburst = '0;
        slave.arcache = '0;
        slave.arlock  = '0;
        slave.arid    = '0;

        // default per-master arready = 0
        arready_flat = '0; // vector assign default for all masters

        if (read_grant_valid) begin
            // select the granted master, copy its fields to the slave and route the slave's
            // ready back to that single master's arready_flat bit
            slave.arvalid = arvalid_flat[read_grant_index];
            slave.araddr  = araddr_flat[read_grant_index];
            slave.arlen   = arlen_flat[read_grant_index];
            slave.arsize  = arsize_flat[read_grant_index];
            slave.arburst = arburst_flat[read_grant_index];
            slave.arcache = arcache_flat[read_grant_index];
            slave.arlock  = arlock_flat[read_grant_index];
            slave.arid    = arid_flat[read_grant_index];

            // single driver: take slave.arready (input from downstream slave) and reflect it
            // to the granted master's arready_flat bit
            arready_flat[read_grant_index] = slave.arready;
        end
    end

    // Slave always ready to accept read data
    assign slave.rready = 1'b1;

    // --- Write channel: mux flattened AW/W into slave (combinational) ---
    always_comb begin
        // defaults for AW (arbiter -> slave)
        slave.awvalid = 1'b0;
        slave.awaddr  = '0;
        slave.awlen   = '0;
        slave.awsize  = '0;
        slave.awburst = '0;
        slave.awcache = '0;
        slave.awlock  = '0;
        slave.awid    = '0;

        // defaults for W (arbiter -> slave)
        slave.wvalid = 1'b0;
        slave.wdata  = '0;
        slave.wstrb  = '0;
        slave.wlast  = 1'b0;

        // default per-master aw/w ready = 0
        awready_flat = '0;
        wready_flat  = '0;

        if (write_grant_valid) begin
            slave.awvalid = awvalid_flat[write_grant_index];
            slave.awaddr  = awaddr_flat[write_grant_index];
            slave.awlen   = awlen_flat[write_grant_index];
            slave.awsize  = awsize_flat[write_grant_index];
            slave.awburst = awburst_flat[write_grant_index];
            slave.awcache = awcache_flat[write_grant_index];
            slave.awlock  = awlock_flat[write_grant_index];
            slave.awid    = awid_flat[write_grant_index];

            slave.wvalid = wvalid_flat[write_grant_index];
            slave.wdata  = wdata_flat[write_grant_index];
            slave.wstrb  = wstrb_flat[write_grant_index];
            slave.wlast  = wlast_flat[write_grant_index];

            // reflect downstream ready signals to the single granted master
            awready_flat[write_grant_index] = slave.awready;
            wready_flat[write_grant_index]  = slave.wready;
        end
    end

    // --- Write response (B) demux: deliver b channel to correct master by matching IDs ---
    always_comb begin
        // defaults
        bvalid_flat = '0;
        bresp_flat  = '0;
        bid_flat    = '0;

        if (slave.bvalid) begin
            // find which master the bresp belongs to by matching AW ID (awid_flat)
            // linear search - okay for small NUM_MASTERS; can be optimized
            for (int k = 0; k < NUM_MASTERS; k++) begin
                if (slave.bid == awid_flat[k]) begin
                    bvalid_flat[k] = 1'b1;
                    bresp_flat[k]  = slave.bresp;
                    bid_flat[k]    = slave.bid;
                end
            end
        end
    end

    // Slave ready for write responses
    assign slave.bready = 1'b1;

    // --- Simple state machines to gate grant_valid signals (combinational outputs) ---
    typedef enum logic [0:0] {IDLE = 1'b0, READ_START = 1'b1} state_t;
    state_t current_state, next_state;

    always_comb begin
        // defaults
        next_state      = current_state;
        read_grant_valid = 1'b0;

        if (current_state == IDLE && |read_request) begin
            read_grant_valid = 1'b1;
            next_state = READ_START;
        end
        else if (current_state == READ_START && slave.rvalid && slave.rready) begin
            read_grant_valid = 1'b0;
            next_state = IDLE;
        end
        else if (current_state == READ_START) begin
            read_grant_valid = 1'b0;
            next_state = READ_START;
        end
    end

    typedef enum logic [0:0] {W_IDLE = 1'b0, WRITE_START = 1'b1} write_state_t;
    write_state_t w_current_state, w_next_state;

    always_comb begin
        // defaults
        w_next_state      = w_current_state;
        write_grant_valid = 1'b0;

        if (w_current_state == W_IDLE && |write_request) begin
            write_grant_valid = 1'b1;
            w_next_state = WRITE_START;
        end
        else if (w_current_state == WRITE_START && slave.bvalid && slave.bready) begin
            write_grant_valid = 1'b0;
            w_next_state = W_IDLE;
        end
        else if (w_current_state == WRITE_START) begin
            write_grant_valid = 1'b0;
            w_next_state = WRITE_START;
        end
    end

    // Sequential state updates
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state  <= IDLE;
            w_current_state <= W_IDLE;
        end else begin
            current_state  <= next_state;
            w_current_state <= w_next_state;
        end
    end

endmodule
