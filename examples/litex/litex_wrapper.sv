/*
 * Copyright © 2022 Eric Matthews, Lesley Shannon
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Initial code developed under the supervision of Dr. Lesley Shannon,
 * Reconfigurable Computing Lab, Simon Fraser University.
 *
 * Author(s):
 *             Eric Matthews <ematthew@sfu.ca>
 */

module litex_wrapper
    import cva5_config::*;
    import cva5_types::*;

    #(
        parameter bit [31:0] RESET_VEC = 0,
        parameter bit [31:0] NON_CACHABLE_L = 32'h80000000,
        parameter bit [31:0] NON_CACHABLE_H = 32'hFFFFFFFF,
        parameter int unsigned NUM_CORES = 1,
        parameter logic AXI = 1'b1 //Else the wishbone bus is used
    )
    (
        input logic clk,
        input logic rst,

        input logic [NUM_CORES-1:0] meip,
        input logic [NUM_CORES-1:0] seip,
        input logic [NUM_CORES-1:0] mtip,
        input logic [NUM_CORES-1:0] msip,
        input logic [63:0] mtime,

        //Wishbone memory port (used only if configured)
        output logic [29:0] idbus_adr,
        output logic [31:0] idbus_dat_w,
        output logic [3:0] idbus_sel,
        output logic idbus_cyc,
        output logic idbus_stb,
        output logic idbus_we,
        output logic idbus_cti,
        output logic idbus_bte,
        input logic [31:0] idbus_dat_r,
        input logic idbus_ack,
        input logic idbus_err,

        //AXI memory port (used only if configured)
        //AR
        input logic m_axi_arready,
        output logic m_axi_arvalid,
        output logic [31:0] m_axi_araddr,
        output logic [7:0] m_axi_arlen,
        output logic [2:0] m_axi_arsize, //Constant, 32b
        output logic [1:0] m_axi_arburst, //Constant, incrementing
        output logic [3:0] m_axi_arcache, //Constant, normal non-cacheable bufferable
        output logic [5:0] m_axi_arid,
        //R
        output logic m_axi_rready,
        input logic m_axi_rvalid,
        input logic [31:0] m_axi_rdata,
        input logic [1:0] m_axi_rresp,
        input logic m_axi_rlast,
        input logic [5:0] m_axi_rid,
        //AW
        input logic m_axi_awready,
        output logic m_axi_awvalid,
        output logic [31:0] m_axi_awaddr,
        output logic [7:0] m_axi_awlen, //Constant, 0
        output logic [2:0] m_axi_awsize, //Constant, 32b
        output logic [1:0] m_axi_awburst, //Constant, incrementing
        output logic [3:0] m_axi_awcache, //Constant, normal non-cacheable bufferable
        output logic [5:0] m_axi_awid,
        //W
        input logic m_axi_wready,
        output logic m_axi_wvalid,
        output logic [31:0] m_axi_wdata,
        output logic [3:0] m_axi_wstrb,
        output logic m_axi_wlast,
        //B
        output logic m_axi_bready,
        input logic m_axi_bvalid,
        input logic [1:0] m_axi_bresp,
        input logic [5:0] m_axi_bid,

        // the arbiter axi


        // AR
        // input logic m_axi_arbiter_arready,
        // output logic m_axi_arbiter_arvalid,
        // output logic [31:0] m_axi_arbiter_araddr,
        // output logic [7:0] m_axi_arbiter_arlen,
        // output logic [2:0] m_axi_arbiter_arsize, //Constant, 32b
        // output logic [1:0] m_axi_arbiter_arburst, //Constant, incrementing
        // output logic [3:0] m_axi_arbiter_arcache, //Constant, normal non-cacheable bufferable
        // output logic [5:0] m_axi_arbiter_arid,
        // //R
        // output logic m_axi_arbiter_rready,
        // input logic m_axi_arbiter_rvalid,
        // input logic [31:0] m_axi_arbiter_rdata,
        // input logic [1:0] m_axi_arbiter_rresp,
        // input logic m_axi_arbiter_rlast,
        // input logic [5:0] m_axi_arbiter_rid,
        // //AW
        // input logic m_axi_arbiter_awready,
        // output logic m_axi_arbiter_awvalid,
        // output logic [31:0] m_axi_arbiter_awaddr,
        // output logic [7:0] m_axi_arbiter_awlen, //Constant, 0
        // output logic [2:0] m_axi_arbiter_awsize, //Constant, 32b
        // output logic [1:0] m_axi_arbiter_awburst, //Constant, incrementing
        // output logic [3:0] m_axi_arbiter_awcache, //Constant, normal non-cacheable bufferable
        // output logic [5:0] m_axi_arbiter_awid,
        // //W
        // input logic m_axi_arbiter_wready,
        // output logic m_axi_arbiter_wvalid,
        // output logic [31:0] m_axi_arbiter_wdata,
        // output logic [3:0] m_axi_arbiter_wstrb,
        // output logic m_axi_arbiter_wlast,
        // //B
        // output logic m_axi_arbiter_bready,
        // input logic m_axi_arbiter_bvalid,
        // input logic [1:0] m_axi_arbiter_bresp,
        // input logic [5:0] m_axi_arbiter_bid,

        // arbiter bram interface
        output logic [31:0] arbiter_bram_addr,
        output logic [31:0] arbiter_bram_wdata,
        input logic [31:0] arbiter_bram_rdata,
        output logic [3:0] arbiter_bram_be,
        output logic arbiter_bram_en
    );

    localparam wb_group_config_t STANDARD_WB_GROUP_CONFIG = '{
        0 : '{0: ALU_ID, default : NON_WRITEBACK_ID},
        1 : '{0: LS_ID, default : NON_WRITEBACK_ID},
        2 : '{0: MUL_ID, 1: DIV_ID, 2: CSR_ID, 3: CUSTOM_ID, default : NON_WRITEBACK_ID},
        default : '{default : NON_WRITEBACK_ID}
    };

    //Unused interfaces
    axi_interface axi[NUM_CORES-1:0]();
    avalon_interface avalon[NUM_CORES-1:0]();
    wishbone_interface dwishbone[NUM_CORES-1:0]();
    wishbone_interface iwishbone[NUM_CORES-1:0]();
    local_memory_interface instruction_bram[NUM_CORES-1:0]();
    local_memory_interface data_bram[NUM_CORES-1:0]();

    //Interrupts
    interrupt_t[NUM_CORES-1:0] s_interrupt;
    interrupt_t[NUM_CORES-1:0] m_interrupt;

    //Memory interfaces for each core
    mem_interface mem[NUM_CORES-1:0]();
    
    generate for (genvar i = 0; i < NUM_CORES; i++) begin : gen_cores
        localparam cpu_config_t STANDARD_CONFIG_I = '{
            //ISA options
            MODES : MSU,
            INCLUDE_UNIT : '{
                MUL : 1,
                DIV : 1,
                CSR : 1,
                FPU : 0,
                CUSTOM : 0,
                default: '0
            },
            INCLUDE_IFENCE : 1,
            INCLUDE_AMO : 1,
            INCLUDE_CBO : 0,
            //CSR constants
            CSRS : '{
                MACHINE_IMPLEMENTATION_ID : 0,
                CPU_ID : i,
                RESET_VEC : RESET_VEC,
                RESET_TVEC : 32'h00000000,
                MCONFIGPTR : '0,
                INCLUDE_ZICNTR : 1,
                INCLUDE_ZIHPM : 1,
                INCLUDE_SSTC : 1,
                INCLUDE_SMSTATEEN : 1
            },
            //Memory Options
            SQ_DEPTH : 4,
            INCLUDE_FORWARDING_TO_STORES : 1,
            AMO_UNIT : '{
                LR_WAIT : 8,
                RESERVATION_WORDS : 8
            },
            INCLUDE_ICACHE : 1,
            ICACHE_ADDR : '{
                L : 32'h00000000,
                H : 32'h7FFFFFFF
            },
            ICACHE : '{
                LINES : 512,
                LINE_W : 8,
                WAYS : 2,
                USE_EXTERNAL_INVALIDATIONS : 0,
                USE_NON_CACHEABLE : 0,
                NON_CACHEABLE : '{
                    L: NON_CACHABLE_L,
                    H: NON_CACHABLE_H
                }
            },
            ITLB : '{
                WAYS : 2,
                DEPTH : 64
            },
            INCLUDE_DCACHE : 1,
            DCACHE_ADDR : '{
                L : 32'h00000000,
                H : 32'hFFFFFFFF
            },
            DCACHE : '{
                LINES : 512,
                LINE_W : 8,
                WAYS : 2,
                USE_EXTERNAL_INVALIDATIONS : 1,
                USE_NON_CACHEABLE : 1,
                NON_CACHEABLE : '{
                    L: NON_CACHABLE_L,
                    H: NON_CACHABLE_H
                }
            },
            DTLB : '{
                WAYS : 2,
                DEPTH : 64
            },
            INCLUDE_ILOCAL_MEM : 0,
            ILOCAL_MEM_ADDR : '{
                L : 32'h80000000,
                H : 32'h8FFFFFFF
            },
            INCLUDE_DLOCAL_MEM : 0,
            DLOCAL_MEM_ADDR : '{
                L : 32'h80000000,
                H : 32'h8FFFFFFF
            },
            INCLUDE_IBUS : 0,
            IBUS_ADDR : '{
                L : 32'h00000000,
                H : 32'hFFFFFFFF
            },
            INCLUDE_PERIPHERAL_BUS : 0,
            PERIPHERAL_BUS_ADDR : '{
                L : 32'h00000000,
                H : 32'hFFFFFFFF
            },
            PERIPHERAL_BUS_TYPE : WISHBONE_BUS,
            //Branch Predictor Options
            INCLUDE_BRANCH_PREDICTOR : 1,
            BP : '{
                WAYS : 2,
                ENTRIES : 512,
                RAS_ENTRIES : 8
            },
            //Writeback Options
            NUM_WB_GROUPS : 3,
            WB_GROUP : STANDARD_WB_GROUP_CONFIG
        };

        assign m_interrupt[i].software = msip[i];
        assign m_interrupt[i].timer = mtip[i];
        assign m_interrupt[i].external = meip[i];
        assign s_interrupt[i].software = 0; //Not possible
        assign s_interrupt[i].timer = 0; //Internal
        assign s_interrupt[i].external = seip[i];

        cva5 #(.CONFIG(STANDARD_CONFIG_I)) cpu(
            .instruction_bram(instruction_bram[i]),
            .data_bram(data_bram[i]),
            .m_axi(axi[i]),
            .m_avalon(avalon[i]),
            .dwishbone(dwishbone[i]),
            .iwishbone(iwishbone[i]),
            .mem(mem[i]),
            .mtime(mtime),
            .s_interrupt(s_interrupt[i]),
            .m_interrupt(m_interrupt[i]),
        .*);

    end endgenerate



    local_memory_interface final_data_bram();
    Bram_Arbiter #(.NUM_MASTERS(NUM_CORES)) bram_arbiter (
        .clk(clk),
        .masters(data_bram),
        .slave(final_data_bram)
    );
    assign arbiter_bram_addr[1:0] = 2'b0;
    // Connect final_data_bram interface to external arbiter BRAM pins
    assign arbiter_bram_addr[31:2]  = final_data_bram.addr;
    assign arbiter_bram_wdata = final_data_bram.data_in;
    assign final_data_bram.data_out  = arbiter_bram_rdata;
    assign arbiter_bram_en    = final_data_bram.en;
    assign arbiter_bram_be    = final_data_bram.be;



    // axi_interface scratch_axi();
    // Axi_Arbiter #(.NUM_MASTERS(NUM_CORES)) axi_arbiter (
    //     .clk(clk),
    //     .rst(rst),
    //     .masters(axi),
    //     .slave(scratch_axi)
    // );
    // axi_crossbar_0 axi_arbiter(aclk, aresetn, s_axi_awid, s_axi_awaddr, 
    // s_axi_awlen, s_axi_awsize, s_axi_awburst, s_axi_awlock, s_axi_awcache, s_axi_awprot, 
    // s_axi_awqos, s_axi_awvalid, s_axi_awready, s_axi_wdata, s_axi_wstrb, s_axi_wlast, 
    // s_axi_wvalid, s_axi_wready, s_axi_bid, s_axi_bresp, s_axi_bvalid, s_axi_bready, s_axi_arid, 
    // s_axi_araddr, s_axi_arlen, s_axi_arsize, s_axi_arburst, s_axi_arlock, s_axi_arcache, 
    // s_axi_arprot, s_axi_arqos, s_axi_arvalid, s_axi_arready, s_axi_rid, s_axi_rdata, s_axi_rresp, 
    // s_axi_rlast, s_axi_rvalid, s_axi_rready, m_axi_awid, m_axi_awaddr, m_axi_awlen, m_axi_awsize, 
    // m_axi_awburst, m_axi_awlock, m_axi_awcache, m_axi_awprot, m_axi_awregion, m_axi_awqos, 
    // m_axi_awvalid, m_axi_awready, m_axi_wdata, m_axi_wstrb, m_axi_wlast, m_axi_wvalid, 
    // m_axi_wready, m_axi_bid, m_axi_bresp, m_axi_bvalid, m_axi_bready, m_axi_arid, m_axi_araddr, 
    // m_axi_arlen, m_axi_arsize, m_axi_arburst, m_axi_arlock, m_axi_arcache, m_axi_arprot, 
    // m_axi_arregion, m_axi_arqos, m_axi_arvalid, m_axi_arready, m_axi_rid, m_axi_rdata, 
    // m_axi_rresp, m_axi_rlast, m_axi_rvalid, m_axi_rready);
    // Declare interface array


    // Extract all widths from axi_interface
    // localparam int ARADDR_W  = 32;
    // localparam int ARLEN_W   = 8;
    // localparam int ARSIZE_W  = 3;
    // localparam int ARBURST_W = 2;
    // localparam int ARCACHE_W = 4;
    // localparam int ARLOCK_W  = 1;
    // localparam int ARID_W    = 6;

    // localparam int AWADDR_W  = 32;
    // localparam int AWLEN_W   = 8;
    // localparam int AWSIZE_W  = 3;
    // localparam int AWBURST_W = 2;
    // localparam int AWCACHE_W = 4;
    // localparam int AWLOCK_W  = 1;
    // localparam int AWID_W    = 6;

    // localparam int WDATA_W   = 32;
    // localparam int WSTRB_W   = 4;
    // localparam int WLAST_W   = 1;

    // localparam int BID_W     = 6;
    // localparam int BRESP_W   = 2;
    // localparam int BVALID_W  = 1;
    // localparam int BREADY_W  = 1;

    // localparam int RID_W     = 6;
    // localparam int RDATA_W   = 32;
    // localparam int RRESP_W   = 2;
    // localparam int RLAST_W   = 1;
    // localparam int RVALID_W  = 1;
    // localparam int RREADY_W  = 1;

    // // These fields were missing in your interface, so we define standard AXI defaults:
    // localparam int AWPROT_W  = 3;  // Typical AXI signal width
    // localparam int AWQOS_W   = 4;  // Typical AXI signal width
    // localparam int ARPROT_W  = 3;  // Typical AXI signal width
    // localparam int ARQOS_W   = 4;  // Typical AXI signal width

    // localparam int AWVALID_W = 1;
    // localparam int AWREADY_W = 1;
    // localparam int WVALID_W  = 1;
    // localparam int WREADY_W  = 1;
    // localparam int ARVALID_W = 1;
    // localparam int ARREADY_W = 1;


    // Create vectors for all s_axi signals using the consistent widths
    // logic [AWID_W*NUM_CORES-1:0]     s_axi_awid_vec;
    // logic [AWADDR_W*NUM_CORES-1:0]   s_axi_awaddr_vec;
    // logic [AWLEN_W*NUM_CORES-1:0]    s_axi_awlen_vec;
    // logic [AWSIZE_W*NUM_CORES-1:0]   s_axi_awsize_vec;
    // logic [AWBURST_W*NUM_CORES-1:0]  s_axi_awburst_vec;
    // logic [AWLOCK_W*NUM_CORES-1:0]   s_axi_awlock_vec;
    // logic [AWCACHE_W*NUM_CORES-1:0]  s_axi_awcache_vec;
    // logic [AWPROT_W*NUM_CORES-1:0]   s_axi_awprot_vec;
    // logic [AWQOS_W*NUM_CORES-1:0]    s_axi_awqos_vec;
    // logic [AWVALID_W*NUM_CORES-1:0]  s_axi_awvalid_vec;
    // logic [AWREADY_W*NUM_CORES-1:0]  s_axi_awready_vec;

    // logic [WDATA_W*NUM_CORES-1:0]    s_axi_wdata_vec;
    // logic [WSTRB_W*NUM_CORES-1:0]    s_axi_wstrb_vec;
    // logic [WLAST_W*NUM_CORES-1:0]    s_axi_wlast_vec;
    // logic [WVALID_W*NUM_CORES-1:0]   s_axi_wvalid_vec;
    // logic [WREADY_W*NUM_CORES-1:0]   s_axi_wready_vec;

    // logic [BID_W*NUM_CORES-1:0]      s_axi_bid_vec;
    // logic [BRESP_W*NUM_CORES-1:0]    s_axi_bresp_vec;
    // logic [BVALID_W*NUM_CORES-1:0]   s_axi_bvalid_vec;
    // logic [BREADY_W*NUM_CORES-1:0]   s_axi_bready_vec;

    // logic [ARID_W*NUM_CORES-1:0]     s_axi_arid_vec;
    // logic [ARADDR_W*NUM_CORES-1:0]   s_axi_araddr_vec;
    // logic [ARLEN_W*NUM_CORES-1:0]    s_axi_arlen_vec;
    // logic [ARSIZE_W*NUM_CORES-1:0]   s_axi_arsize_vec;
    // logic [ARBURST_W*NUM_CORES-1:0]  s_axi_arburst_vec;
    // logic [ARLOCK_W*NUM_CORES-1:0]   s_axi_arlock_vec;
    // logic [ARCACHE_W*NUM_CORES-1:0]  s_axi_arcache_vec;
    // logic [ARPROT_W*NUM_CORES-1:0]   s_axi_arprot_vec;
    // logic [ARQOS_W*NUM_CORES-1:0]    s_axi_arqos_vec;
    // logic [ARVALID_W*NUM_CORES-1:0]  s_axi_arvalid_vec;
    // logic [ARREADY_W*NUM_CORES-1:0]  s_axi_arready_vec;

    // logic [RID_W*NUM_CORES-1:0]      s_axi_rid_vec;
    // logic [RDATA_W*NUM_CORES-1:0]    s_axi_rdata_vec;
    // logic [RRESP_W*NUM_CORES-1:0]    s_axi_rresp_vec;
    // logic [RLAST_W*NUM_CORES-1:0]    s_axi_rlast_vec;
    // logic [RVALID_W*NUM_CORES-1:0]   s_axi_rvalid_vec;
    // logic [RREADY_W*NUM_CORES-1:0]   s_axi_rready_vec;


    // Use generate loops to assign slices from interface array
    // genvar i;
    // generate
    //     for (i=0; i<NUM_CORES; i=i+1) begin
    //         // AW channel
    //         assign s_axi_awid_vec[AWID_W*(i+1)-1 -: AWID_W]       = axi[i].awid;
    //         assign s_axi_awaddr_vec[AWADDR_W*(i+1)-1 -: AWADDR_W] = axi[i].awaddr;
    //         assign s_axi_awlen_vec[AWLEN_W*(i+1)-1 -: AWLEN_W]    = axi[i].awlen;
    //         assign s_axi_awsize_vec[AWSIZE_W*(i+1)-1 -: AWSIZE_W] = axi[i].awsize;
    //         assign s_axi_awburst_vec[AWBURST_W*(i+1)-1 -: AWBURST_W] = axi[i].awburst;
    //         assign s_axi_awlock_vec[AWLOCK_W*(i+1)-1 -: AWLOCK_W] = axi[i].awlock;
    //         assign s_axi_awcache_vec[AWCACHE_W*(i+1)-1 -: AWCACHE_W] = axi[i].awcache;
    //         // assign s_axi_awprot_vec[AWPROT_W*(i+1)-1 -: AWPROT_W] = axi[i].awprot;
    //         // assign s_axi_awqos_vec[AWQOS_W*(i+1)-1 -: AWQOS_W]    = axi[i].awqos;
    //         assign s_axi_awvalid_vec[AWVALID_W*(i+1)-1 -: AWVALID_W] = axi[i].awvalid;
    //         assign s_axi_awready_vec[AWREADY_W*(i+1)-1 -: AWREADY_W] = axi[i].awready;

    //         // Repeat for W channel
    //         assign s_axi_wdata_vec[WDATA_W*(i+1)-1 -: WDATA_W] = axi[i].wdata;
    //         assign s_axi_wstrb_vec[WSTRB_W*(i+1)-1 -: WSTRB_W] = axi[i].wstrb;
    //         assign s_axi_wlast_vec[WLAST_W*(i+1)-1 -: WLAST_W] = axi[i].wlast;
    //         assign s_axi_wvalid_vec[WVALID_W*(i+1)-1 -: WVALID_W] = axi[i].wvalid;
    //         assign s_axi_wready_vec[WREADY_W*(i+1)-1 -: WREADY_W] = axi[i].wready;

    //         // B channel
    //         assign s_axi_bid_vec[BID_W*(i+1)-1 -: BID_W]       = axi[i].bid;
    //         assign s_axi_bresp_vec[BRESP_W*(i+1)-1 -: BRESP_W] = axi[i].bresp;
    //         assign s_axi_bvalid_vec[BVALID_W*(i+1)-1 -: BVALID_W] = axi[i].bvalid;
    //         assign s_axi_bready_vec[BREADY_W*(i+1)-1 -: BREADY_W] = axi[i].bready;

    //         // AR channel
    //         assign s_axi_arid_vec[ARID_W*(i+1)-1 -: ARID_W]       = axi[i].arid;
    //         assign s_axi_araddr_vec[ARADDR_W*(i+1)-1 -: ARADDR_W] = axi[i].araddr;
    //         assign s_axi_arlen_vec[ARLEN_W*(i+1)-1 -: ARLEN_W]    = axi[i].arlen;
    //         assign s_axi_arsize_vec[ARSIZE_W*(i+1)-1 -: ARSIZE_W] = axi[i].arsize;
    //         assign s_axi_arburst_vec[ARBURST_W*(i+1)-1 -: ARBURST_W] = axi[i].arburst;
    //         assign s_axi_arlock_vec[ARLOCK_W*(i+1)-1 -: ARLOCK_W] = axi[i].arlock;
    //         assign s_axi_arcache_vec[ARCACHE_W*(i+1)-1 -: ARCACHE_W] = axi[i].arcache;
    //         // assign s_axi_arprot_vec[ARPROT_W*(i+1)-1 -: ARPROT_W] = axi[i].arprot;
    //         // assign s_axi_arqos_vec[ARQOS_W*(i+1)-1 -: ARQOS_W]    = axi[i].arqos;
    //         assign s_axi_arvalid_vec[ARVALID_W*(i+1)-1 -: ARVALID_W] = axi[i].arvalid;
    //         assign s_axi_arready_vec[ARREADY_W*(i+1)-1 -: ARREADY_W] = axi[i].arready;

    //         // R channel
    //         assign s_axi_rid_vec[RID_W*(i+1)-1 -: RID_W]       = axi[i].rid;
    //         assign s_axi_rdata_vec[RDATA_W*(i+1)-1 -: RDATA_W] = axi[i].rdata;
    //         assign s_axi_rresp_vec[RRESP_W*(i+1)-1 -: RRESP_W] = axi[i].rresp;
    //         assign s_axi_rlast_vec[RLAST_W*(i+1)-1 -: RLAST_W] = axi[i].rlast;
    //         assign s_axi_rvalid_vec[RVALID_W*(i+1)-1 -: RVALID_W] = axi[i].rvalid;
    //         assign s_axi_rready_vec[RREADY_W*(i+1)-1 -: RREADY_W] = axi[i].rready;

    //     end
    // endgenerate

    // ila_1 ila (
    //     .clk(clk), // input wire clk
    //     .probe0(s_axi_awvalid_vec), // input wire [0:0]  probe0  
    //     .probe1(s_axi_awready_vec), // input wire [1:0]  probe1 
    //     .probe2(s_axi_wvalid_vec), // input wire [0:0]  probe2
    //     .probe3(s_axi_wready_vec), // input wire [1:0]  probe3
    //     .probe4(s_axi_bready_vec), // input wire [0:0]  probe4
    //     .probe5(s_axi_bvalid_vec),
    //     .probe6(s_axi_arvalid_vec), // input wire [0:0]  probe6
    //     .probe7(s_axi_arready_vec), // input wire [1:0]
    //     .probe8(s_axi_rready_vec), // input wire [0:0]  probe8
    //     .probe9(s_axi_rvalid_vec) // input wire [1:0]
    // );

    // Instantiate the crossbar
    // axi_crossbar_0 axi_arbiter (
    //     .aclk        (clk),
    //     .aresetn     (~rst),

    //     // Master signals
    //     .s_axi_awid      (s_axi_awid_vec),
    //     .s_axi_awaddr    (s_axi_awaddr_vec),
    //     .s_axi_awlen     (s_axi_awlen_vec),
    //     .s_axi_awsize    (s_axi_awsize_vec),
    //     .s_axi_awburst   (s_axi_awburst_vec),
    //     .s_axi_awlock    (s_axi_awlock_vec),
    //     .s_axi_awcache   (s_axi_awcache_vec),
    //     // .s_axi_awprot    (s_axi_awprot_vec),
    //     // .s_axi_awqos     (s_axi_awqos_vec),
    //     .s_axi_awvalid   (s_axi_awvalid_vec),
    //     .s_axi_awready   (s_axi_awready_vec),
    //     .s_axi_wdata     (s_axi_wdata_vec),
    //     .s_axi_wstrb     (s_axi_wstrb_vec),
    //     .s_axi_wlast     (s_axi_wlast_vec),
    //     .s_axi_wvalid    (s_axi_wvalid_vec),
    //     .s_axi_wready    (s_axi_wready_vec),
    //     .s_axi_bid       (s_axi_bid_vec),
    //     .s_axi_bresp     (s_axi_bresp_vec),
    //     .s_axi_bvalid    (s_axi_bvalid_vec),
    //     .s_axi_bready    (s_axi_bready_vec),
    //     .s_axi_arid      (s_axi_arid_vec),
    //     .s_axi_araddr    (s_axi_araddr_vec),
    //     .s_axi_arlen     (s_axi_arlen_vec),
    //     .s_axi_arsize    (s_axi_arsize_vec),
    //     .s_axi_arburst   (s_axi_arburst_vec),
    //     .s_axi_arlock    (s_axi_arlock_vec),
    //     .s_axi_arcache   (s_axi_arcache_vec),
    //     // .s_axi_arprot    (s_axi_arprot_vec),
    //     // .s_axi_arqos     (s_axi_arqos_vec),
    //     .s_axi_arvalid   (s_axi_arvalid_vec),
    //     .s_axi_arready   (s_axi_arready_vec),
    //     .s_axi_rid       (s_axi_rid_vec),
    //     .s_axi_rdata     (s_axi_rdata_vec),
    //     .s_axi_rresp     (s_axi_rresp_vec),
    //     .s_axi_rlast     (s_axi_rlast_vec),
    //     .s_axi_rvalid    (s_axi_rvalid_vec),
    //     .s_axi_rready    (s_axi_rready_vec),

    //     // Slave signals
    //     .m_axi_awid      (m_axi_arbiter_awid),
    //     .m_axi_awaddr    (m_axi_arbiter_awaddr),
    //     .m_axi_awlen     (m_axi_arbiter_awlen),
    //     .m_axi_awsize    (m_axi_arbiter_awsize),
    //     .m_axi_awburst   (m_axi_arbiter_awburst),
    //     .m_axi_awlock    (m_axi_arbiter_awlock),
    //     .m_axi_awcache   (m_axi_arbiter_awcache),
    //     // .m_axi_awprot    (m_axi_arbiter_awprot),
    //     // .m_axi_awregion  (m_axi_arbiter_awregion),
    //     // .m_axi_awqos     (m_axi_arbiter_awqos),
    //     .m_axi_awvalid   (m_axi_arbiter_awvalid),
    //     .m_axi_awready   (m_axi_arbiter_awready),
    //     .m_axi_wdata     (m_axi_arbiter_wdata),
    //     .m_axi_wstrb     (m_axi_arbiter_wstrb),
    //     .m_axi_wlast     (m_axi_arbiter_wlast),
    //     .m_axi_wvalid    (m_axi_arbiter_wvalid),
    //     .m_axi_wready    (m_axi_arbiter_wready),
    //     .m_axi_bid       (m_axi_arbiter_bid),
    //     .m_axi_bresp     (m_axi_arbiter_bresp),
    //     .m_axi_bvalid    (m_axi_arbiter_bvalid),
    //     .m_axi_bready    (m_axi_arbiter_bready),
    //     .m_axi_arid      (m_axi_arbiter_arid),
    //     .m_axi_araddr    (m_axi_arbiter_araddr),
    //     .m_axi_arlen     (m_axi_arbiter_arlen),
    //     .m_axi_arsize    (m_axi_arbiter_arsize),
    //     .m_axi_arburst   (m_axi_arbiter_arburst),
    //     .m_axi_arlock    (m_axi_arbiter_arlock),
    //     .m_axi_arcache   (m_axi_arbiter_arcache),
    //     // .m_axi_arprot    (m_axi_arbiter_arprot),
    //     // .m_axi_arregion  (m_axi_arbiter_arregion),
    //     // .m_axi_arqos     (m_axi_arbiter_arqos),
    //     .m_axi_arvalid   (m_axi_arbiter_arvalid),
    //     .m_axi_arready   (m_axi_arbiter_arready),
    //     .m_axi_rid       (m_axi_arbiter_rid),
    //     .m_axi_rdata     (m_axi_arbiter_rdata),
    //     .m_axi_rresp     (m_axi_arbiter_rresp),
    //     .m_axi_rlast     (m_axi_arbiter_rlast),
    //     .m_axi_rvalid    (m_axi_arbiter_rvalid),
    //     .m_axi_rready    (m_axi_arbiter_rready)
    // );

    // assign scratch_axi.arready = m_axi_arbiter_arready;
    // assign m_axi_arbiter_arvalid = scratch_axi.arvalid;
    // assign m_axi_arbiter_araddr = scratch_axi.araddr;
    // assign m_axi_arbiter_arlen = scratch_axi.arlen;
    // assign m_axi_arbiter_arsize = scratch_axi.arsize;
    // assign m_axi_arbiter_arburst = scratch_axi.arburst;
    // assign m_axi_arbiter_arcache = scratch_axi.arcache;
    // assign m_axi_arbiter_arid = scratch_axi.arid;

    // assign m_axi_arbiter_rready = scratch_axi.rready;
    // assign scratch_axi.rvalid = m_axi_arbiter_rvalid;
    // assign scratch_axi.rdata  = m_axi_arbiter_rdata;
    // assign scratch_axi.rresp = m_axi_arbiter_rresp;
    // assign scratch_axi.rlast = m_axi_arbiter_rlast;
    // assign scratch_axi.rid  = m_axi_arbiter_rid;

    // assign scratch_axi.awready = m_axi_arbiter_awready;
    // assign m_axi_arbiter_awvalid = scratch_axi.awvalid;
    // assign m_axi_arbiter_awaddr = scratch_axi.awaddr;
    // assign m_axi_arbiter_awlen = scratch_axi.awlen;
    // assign m_axi_arbiter_awsize = scratch_axi.awsize;
    // assign m_axi_arbiter_awburst = scratch_axi.awburst;
    // assign m_axi_arbiter_awcache = scratch_axi.awcache;
    // assign m_axi_arbiter_awid = scratch_axi.awid;

    // assign scratch_axi.wready = m_axi_arbiter_wready;
    // assign m_axi_arbiter_wvalid = scratch_axi.wvalid;
    // assign m_axi_arbiter_wdata = scratch_axi.wdata;
    // assign m_axi_arbiter_wstrb = scratch_axi.wstrb;
    // assign m_axi_arbiter_wlast = scratch_axi.wlast;

    // assign m_axi_arbiter_bready = scratch_axi.bready;
    // assign scratch_axi.bvalid = m_axi_arbiter_bvalid;
    // assign scratch_axi.bresp = m_axi_arbiter_bresp;
    // assign scratch_axi.bid =  m_axi_arbiter_bid;

    
    //Final memory interface
    generate if (AXI) begin : gen_axi_if
        axi_interface m_axi();

        //Mux requests from one or more cores onto the AXI bus
        axi_adapter #(.NUM_CORES(NUM_CORES)) axi_adapter (
            .mems(mem),
            .axi(m_axi),
        .*);

        assign m_axi.arready = m_axi_arready;
        assign m_axi_arvalid = m_axi.arvalid;
        assign m_axi_araddr = m_axi.araddr;
        assign m_axi_arlen = m_axi.arlen;
        assign m_axi_arsize = m_axi.arsize;
        assign m_axi_arburst = m_axi.arburst;
        assign m_axi_arcache = m_axi.arcache;
        assign m_axi_arid = m_axi.arid;

        assign m_axi_rready = m_axi.rready;
        assign m_axi.rvalid = m_axi_rvalid;
        assign m_axi.rdata  = m_axi_rdata;
        assign m_axi.rresp = m_axi_rresp;
        assign m_axi.rlast = m_axi_rlast;
        assign m_axi.rid  = m_axi_rid;

        assign m_axi.awready = m_axi_awready;
        assign m_axi_awvalid = m_axi.awvalid;
        assign m_axi_awaddr = m_axi.awaddr;
        assign m_axi_awlen = m_axi.awlen;
        assign m_axi_awsize = m_axi.awsize;
        assign m_axi_awburst = m_axi.awburst;
        assign m_axi_awcache = m_axi.awcache;
        assign m_axi_awid = m_axi.awid;

        assign m_axi.wready = m_axi_wready;
        assign m_axi_wvalid = m_axi.wvalid;
        assign m_axi_wdata = m_axi.wdata;
        assign m_axi_wstrb = m_axi.wstrb;
        assign m_axi_wlast = m_axi.wlast;

        assign m_axi_bready = m_axi.bready;
        assign m_axi.bvalid = m_axi_bvalid;
        assign m_axi.bresp = m_axi_bresp;
        assign m_axi.bid =  m_axi_bid;
    end else begin : gen_wishbone_if
        wishbone_interface idwishbone();

        //Mux requests from one or more cores onto the wishbone bus
        wishbone_adapter #(.NUM_CORES(NUM_CORES)) wb_adapter (
            .mems(mem),
            .wishbone(idwishbone),
        .*);

        assign idbus_adr = idwishbone.adr;
        assign idbus_dat_w = idwishbone.dat_w;
        assign idbus_sel = idwishbone.sel;
        assign idbus_cyc = idwishbone.cyc;
        assign idbus_stb = idwishbone.stb;
        assign idbus_we = idwishbone.we;
        assign idbus_cti = idwishbone.cti;
        assign idbus_bte = idwishbone.bte;
        assign idwishbone.dat_r = idbus_dat_r;
        assign idwishbone.ack = idbus_ack;
        assign idwishbone.err = idbus_err;
    end endgenerate

endmodule
