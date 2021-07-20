////////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2021, Modfs https://github.com/modfs
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2020-2021, Gisselquist Technology, LLC
// {{{
//
// This file is part of the WB2AXIP project.
//
// The WB2AXIP project contains free software and gateware, licensed under the
// Apache License, Version 2.0 (the "License").  You may not use this project,
// or this file, except in compliance with the License.  You may obtain a copy
// of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations
// under the License.
//
////////////////////////////////////////////////////////////////////////////////
// }}}
//
`default_nettype none
//
module	miner_saxil #(
		// {{{
		//
		// Size of the AXI-lite bus.  These are fixed, since 1) AXI-lite
		// is fixed at a width of 32-bits by Xilinx def'n, and 2) since
		// we only ever have 4 configuration words.
		parameter	C_AXI_ADDR_WIDTH = 9,
		localparam	C_AXI_DATA_WIDTH = 32,
		parameter [0:0]	OPT_SKIDBUFFER = 1'b0,
		parameter [0:0]	OPT_LOWPOWER = 0,
		localparam	ADDRLSB = $clog2(C_AXI_DATA_WIDTH)-3
		// }}}
	) (
		// {{{
		input	wire					S_AXI_ACLK,
		input	wire					S_AXI_ARESETN,
		//
		input	wire					S_AXI_AWVALID,
		output	wire					S_AXI_AWREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_AWADDR,
		input	wire	[2:0]				S_AXI_AWPROT,
		//
		input	wire					S_AXI_WVALID,
		output	wire					S_AXI_WREADY,
		input	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_WDATA,
		input	wire	[C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB,
		//
		output	wire					S_AXI_BVALID,
		input	wire					S_AXI_BREADY,
		output	wire	[1:0]				S_AXI_BRESP,
		//
		input	wire					S_AXI_ARVALID,
		output	wire					S_AXI_ARREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_ARADDR,
		input	wire	[2:0]				S_AXI_ARPROT,
		//
		output	wire					S_AXI_RVALID,
		input	wire					S_AXI_RREADY,
		output	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_RDATA,
		output	wire	[1:0]				S_AXI_RRESP,
		// }}}
	
	   output wire [3:0] interrupts,
       output wire [63:0] interuptZeroData,
       input wire interuptZeroAck,
       input wire GoodNonceFound,
	   input wire [63:0] NonceOut,
	   output wire nHashRst,
	   output wire [1727:0] WorkPkt,
	   output wire [63:0] InNonce,
	   output wire [63:0] target
	  	);

	

	
	////////////////////////////////////////////////////////////////////////
	//
	// Register/wire signal declarations
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{
	wire	i_reset = !S_AXI_ARESETN;

	wire				axil_write_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	awskd_addr;
	//
	wire	[C_AXI_DATA_WIDTH-1:0]	wskd_data;
	wire [C_AXI_DATA_WIDTH/8-1:0]	wskd_strb;
	reg				axil_bvalid;
	//
	wire				axil_read_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	arskd_addr;
	reg	[C_AXI_DATA_WIDTH-1:0]	axil_read_data;
	reg				axil_read_valid;

	reg	[C_AXI_DATA_WIDTH-1:0]	r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,
                                r16,r17,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27,r28,r29,r30,r31,
                                r32,r33,r34,r35,r36,r37,r38,r39,r40,r41,r42,r43,r44,r45,r46,r47,
                                r48,r49,r50,r51,r52,r53,r54,r55,r56,r57,r58,r59,r60,r61,r62,r63;
	
	
	
	
	
	
	wire	[C_AXI_DATA_WIDTH-1:0]	wskd_r0,wskd_r1,wskd_r2,wskd_r3,wskd_r4,wskd_r5,wskd_r6,wskd_r7,wskd_r8,wskd_r9,wskd_r10,wskd_r11,wskd_r12,wskd_r13,wskd_r14,wskd_r15,
            wskd_r16,wskd_r17,wskd_r18,wskd_r19,wskd_r20,wskd_r21,wskd_r22,wskd_r23,wskd_r24,wskd_r25,wskd_r26,wskd_r27,wskd_r28,wskd_r29,wskd_r30,wskd_r31,
            wskd_r32,wskd_r33,wskd_r34,wskd_r35,wskd_r36,wskd_r37,wskd_r38,wskd_r39,wskd_r40,wskd_r41,wskd_r42,wskd_r43,wskd_r44,wskd_r45,wskd_r46,wskd_r47,
            wskd_r48,wskd_r49,wskd_r50,wskd_r51,wskd_r52,wskd_r53,wskd_r54,wskd_r55,wskd_r56,wskd_r57,wskd_r58,wskd_r59,wskd_r60,wskd_r61,wskd_r62,wskd_r63;
	
	reg [63:0] nonce;
	reg interrupt;
    reg hrst;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite signaling
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	//
	// Write signaling
	//
	// {{{

	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_WRITE
		// {{{
		wire	awskd_valid, wskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilawskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_AWVALID), .o_ready(S_AXI_AWREADY),
			.i_data(S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(awskd_valid), .i_ready(axil_write_ready),
			.o_data(awskd_addr));

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_DATA_WIDTH+C_AXI_DATA_WIDTH/8))
		axilwskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_WVALID), .o_ready(S_AXI_WREADY),
			.i_data({ S_AXI_WDATA, S_AXI_WSTRB }),
			.o_valid(wskd_valid), .i_ready(axil_write_ready),
			.o_data({ wskd_data, wskd_strb }));

		assign	axil_write_ready = awskd_valid && wskd_valid
				&& (!S_AXI_BVALID || S_AXI_BREADY);
		// }}}
	end else begin : SIMPLE_WRITES
		// {{{
		reg	axil_awready;

		initial	axil_awready = 1'b0;
		always @(posedge S_AXI_ACLK)
		if (!S_AXI_ARESETN)
			axil_awready <= 1'b0;
		else
			axil_awready <= !axil_awready
				&& (S_AXI_AWVALID && S_AXI_WVALID)
				&& (!S_AXI_BVALID || S_AXI_BREADY);

		assign	S_AXI_AWREADY = axil_awready;
		assign	S_AXI_WREADY  = axil_awready;

		assign 	awskd_addr = S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	wskd_data  = S_AXI_WDATA;
		assign	wskd_strb  = S_AXI_WSTRB;

		assign	axil_write_ready = axil_awready;
		// }}}
	end endgenerate

	initial	axil_bvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_bvalid <= 0;
	else if (axil_write_ready)
		axil_bvalid <= 1;
	else if (S_AXI_BREADY)
		axil_bvalid <= 0;

	assign	S_AXI_BVALID = axil_bvalid;
	assign	S_AXI_BRESP = 2'b00;
	// }}}

	//
	// Read signaling
	//
	// {{{

	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_READ
		// {{{
		wire	arskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilarskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_ARVALID), .o_ready(S_AXI_ARREADY),
			.i_data(S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(arskd_valid), .i_ready(axil_read_ready),
			.o_data(arskd_addr));

		assign	axil_read_ready = arskd_valid
				&& (!axil_read_valid || S_AXI_RREADY);
		// }}}
	end else begin : SIMPLE_READS
		// {{{
		reg	axil_arready;

		always @(*)
			axil_arready = !S_AXI_RVALID;

		assign	arskd_addr = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	S_AXI_ARREADY = axil_arready;
		assign	axil_read_ready = (S_AXI_ARVALID && S_AXI_ARREADY);
		// }}}
	end endgenerate

	initial	axil_read_valid = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_read_valid <= 1'b0;
	else if (axil_read_ready)
		axil_read_valid <= 1'b1;
	else if (S_AXI_RREADY)
		axil_read_valid <= 1'b0;

	assign	S_AXI_RVALID = axil_read_valid;
	assign	S_AXI_RDATA  = axil_read_data;
	assign	S_AXI_RRESP = 2'b00;
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite register logic
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	// apply_wstrb(old_data, new_data, write_strobes)
	assign	wskd_r0 = apply_wstrb(r0, wskd_data, wskd_strb);
	assign	wskd_r1 = apply_wstrb(r1, wskd_data, wskd_strb);
	assign	wskd_r2 = apply_wstrb(r2, wskd_data, wskd_strb);
	assign	wskd_r3 = apply_wstrb(r3, wskd_data, wskd_strb);
    assign	wskd_r4 = apply_wstrb(r4, wskd_data, wskd_strb);
    assign	wskd_r5 = apply_wstrb(r5, wskd_data, wskd_strb);
    assign	wskd_r6 = apply_wstrb(r6, wskd_data, wskd_strb);
    assign	wskd_r7 = apply_wstrb(r7, wskd_data, wskd_strb);
    assign	wskd_r8 = apply_wstrb(r8, wskd_data, wskd_strb);
    assign	wskd_r9 = apply_wstrb(r9, wskd_data, wskd_strb);
    assign	wskd_r10 = apply_wstrb(r10, wskd_data, wskd_strb);
    assign	wskd_r11 = apply_wstrb(r11, wskd_data, wskd_strb);
    assign	wskd_r12 = apply_wstrb(r12, wskd_data, wskd_strb);
    assign	wskd_r13 = apply_wstrb(r13, wskd_data, wskd_strb);
    assign	wskd_r14 = apply_wstrb(r14, wskd_data, wskd_strb);
    assign	wskd_r15 = apply_wstrb(r15, wskd_data, wskd_strb);
    assign	wskd_r16 = apply_wstrb(r16, wskd_data, wskd_strb);
    assign	wskd_r17 = apply_wstrb(r17, wskd_data, wskd_strb);
    assign	wskd_r18 = apply_wstrb(r18, wskd_data, wskd_strb);
    assign	wskd_r19 = apply_wstrb(r19, wskd_data, wskd_strb);
    assign	wskd_r20 = apply_wstrb(r20, wskd_data, wskd_strb);
    assign	wskd_r21 = apply_wstrb(r21, wskd_data, wskd_strb);
    assign	wskd_r22 = apply_wstrb(r22, wskd_data, wskd_strb);
    assign	wskd_r23 = apply_wstrb(r23, wskd_data, wskd_strb);
	assign	wskd_r24 = apply_wstrb(r24, wskd_data, wskd_strb);
	assign	wskd_r25 = apply_wstrb(r25, wskd_data, wskd_strb);
	assign	wskd_r26 = apply_wstrb(r26, wskd_data, wskd_strb);
    assign	wskd_r27 = apply_wstrb(r27, wskd_data, wskd_strb);
    assign	wskd_r28 = apply_wstrb(r28, wskd_data, wskd_strb);
    assign	wskd_r29 = apply_wstrb(r29, wskd_data, wskd_strb);
    assign	wskd_r30 = apply_wstrb(r30, wskd_data, wskd_strb);
    assign	wskd_r31 = apply_wstrb(r31, wskd_data, wskd_strb);
    assign	wskd_r32 = apply_wstrb(r32, wskd_data, wskd_strb);
    assign	wskd_r33 = apply_wstrb(r33, wskd_data, wskd_strb);
    assign	wskd_r34 = apply_wstrb(r34, wskd_data, wskd_strb);
    assign	wskd_r35 = apply_wstrb(r35, wskd_data, wskd_strb);
    assign	wskd_r36 = apply_wstrb(r36, wskd_data, wskd_strb);
    assign	wskd_r37 = apply_wstrb(r37, wskd_data, wskd_strb);
    assign	wskd_r38 = apply_wstrb(r38, wskd_data, wskd_strb);
    assign	wskd_r39 = apply_wstrb(r39, wskd_data, wskd_strb);
    assign	wskd_r40 = apply_wstrb(r40, wskd_data, wskd_strb);
    assign	wskd_r41 = apply_wstrb(r41, wskd_data, wskd_strb);
    assign	wskd_r42 = apply_wstrb(r42, wskd_data, wskd_strb);
    assign	wskd_r43 = apply_wstrb(r43, wskd_data, wskd_strb);
    assign	wskd_r44 = apply_wstrb(r44, wskd_data, wskd_strb);
	assign	wskd_r45 = apply_wstrb(r45, wskd_data, wskd_strb);
	assign	wskd_r46 = apply_wstrb(r46, wskd_data, wskd_strb);
	assign	wskd_r47 = apply_wstrb(r47, wskd_data, wskd_strb);
    assign	wskd_r48 = apply_wstrb(r48, wskd_data, wskd_strb);
    assign	wskd_r49 = apply_wstrb(r49, wskd_data, wskd_strb);
    assign	wskd_r50 = apply_wstrb(r50, wskd_data, wskd_strb);
    assign	wskd_r51 = apply_wstrb(r51, wskd_data, wskd_strb);
    assign	wskd_r52 = apply_wstrb(r52, wskd_data, wskd_strb);
    assign	wskd_r53 = apply_wstrb(r53, wskd_data, wskd_strb);
    assign	wskd_r54 = apply_wstrb(r54, wskd_data, wskd_strb);
    assign	wskd_r55 = apply_wstrb(r55, wskd_data, wskd_strb);
    assign	wskd_r56 = apply_wstrb(r56, wskd_data, wskd_strb);
    assign	wskd_r57 = apply_wstrb(r57, wskd_data, wskd_strb);
    assign	wskd_r58 = apply_wstrb(r58, wskd_data, wskd_strb);
    assign	wskd_r59 = apply_wstrb(r59, wskd_data, wskd_strb);
    assign	wskd_r60 = apply_wstrb(r60, wskd_data, wskd_strb);
    assign	wskd_r61 = apply_wstrb(r61, wskd_data, wskd_strb);
    assign	wskd_r62 = apply_wstrb(r62, wskd_data, wskd_strb);
    assign	wskd_r63 = apply_wstrb(r63, wskd_data, wskd_strb);
   
    
    
    assign interrupts[0]=interrupt;
    assign interuptZeroData=nonce;
    assign WorkPkt ={r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27,r28,r29,
                     r30,r31,r32,r33,r34,r35,r36,r37,r38,r39,r40,r41,r42,r43,r44,r45,r46,r47,r48,r49,r50,r51,r52,r53,r54};
    assign InNonce ={r56,r55};
    assign target ={r58,r57};
    assign nHashRst =hrst;
    
	initial r0= 0;
	initial r1= 0;
	initial r2= 0;
	initial r3= 0;
	initial r4= 0;
	initial r5= 0;
	initial r6= 0;
	initial r7= 0;
	initial r8= 0;
	initial r9= 0;
	initial r10= 0;
	initial r11= 0;
	initial r12= 0;
	initial r13= 0;
	initial r14= 0;
	initial r15= 0;
	initial r16= 0;
	initial r17= 0;
	initial r18= 0;
	initial r19= 0;
	initial r20= 0;
	initial r21= 0;
	initial r22= 0;
	initial r23= 0;
	initial r24= 0;
	initial r25= 0;
	initial r26= 0;
	initial r27= 0;
	initial r28= 0;
	initial r29= 0;
	initial r30= 0;
	initial r31= 0;
	initial r32= 0;
	initial r33= 0;
	initial r34= 0;
	initial r35= 0;
	initial r36= 0;
	initial r37= 0;
	initial r38= 0;
	initial r39= 0;
	initial r40= 0;
	initial r41= 0;
	initial r42= 0;
	initial r43= 0;
	initial r44= 0;
	initial r45= 0;
	initial r46= 0;
	initial r47= 0;
	initial r48= 0;
	initial r49= 0;
	initial r50= 0;
	initial r51= 0;
	initial r52= 0;
	initial r53= 0;
	initial r54= 0;
	initial r55= 0;
	initial r56= 0;
	initial r57= 0;
	initial r58= 0;
	initial r59= 0;
	initial r60= 0;
	initial r61= 0;
	initial r62= 0;
	initial r63= 0;

	


	always @(posedge S_AXI_ACLK)
	if (i_reset)
	begin
	 r0<= 0;
	 r1<= 0;
	 r2<= 0;
	 r3<= 0;
	 r4<= 0;
	 r5<= 0;
	 r6<= 0;
	 r7<= 0;
	 r8<= 0;
	 r9<= 0;
	 r10<= 0;
	 r11<= 0;
	 r12<= 0;
	 r13<= 0;
	 r14<= 0;
	 r15<= 0;
	 r16<= 0;
	 r17<= 0;
	 r18<= 0;
	 r19<= 0;
	 r20<= 0;
	 r21<= 0;
	 r22<= 0;
	 r23<= 0;
	 r24<= 0;
	 r25<= 0;
	 r26<= 0;
	 r27<= 0;
	 r28<= 0;
	 r29<= 0;
	 r30<= 0;
	 r31<= 0;
	 r32<= 0;
	 r33<= 0;
	 r34<= 0;
	 r35<= 0;
	 r36<= 0;
	 r37<= 0;
	 r38<= 0;
	 r39<= 0;
	 r40<= 0;
	 r41<= 0;
	 r42<= 0;
	 r43<= 0;
	 r44<= 0;
	 r45<= 0;
	 r46<= 0;
	 r47<= 0;
	 r48<= 0;
	 r49<= 0;
	 r50<= 0;
	 r51<= 0;
	 r52<= 0;
	 r53<= 0;
	 r54<= 0;
	 r55<= 0;
	 r56<= 0;
	 r57<= 0;
	 r58<= 0;
	 r59<= 0;
	 r60<= 0;
	 r61<= 0;
	 r62<= 0;
	 r63<= 32'h00000001;
	 hrst<=0;
	end else if (axil_write_ready)
	begin
		case(awskd_addr)
			7'h00:	 r0<=  wskd_r0;
			7'h01:	 r1<=  wskd_r1;
			7'h02:	 r2<=  wskd_r2;
			7'h03:	 r3<=  wskd_r3;
			7'h04:	 r4<=  wskd_r4;
			7'h05:	 r5<=  wskd_r5;
			7'h06:	 r6<=  wskd_r6;
			7'h07:	 r7<=  wskd_r7;
			7'h08:	 r8<=  wskd_r8;
			7'h09:	 r9<=  wskd_r9;
			7'h0A:	 r10<=  wskd_r10;
			7'h0B:	 r11<=  wskd_r11;
			7'h0C:	 r12<=  wskd_r12;
			7'h0D:	 r13<=  wskd_r13;
			7'h0E:	 r14<=  wskd_r14;
			7'h0F:	 r15<=  wskd_r15;
			7'h10:	 r16<=  wskd_r16;
			7'h11:	 r17<=  wskd_r17;
			7'h12:	 r18<=  wskd_r18;
			7'h13:	 r19<=  wskd_r19;
			7'h14:	 r20<=  wskd_r20;
			7'h15:	 r21<=  wskd_r21;
			7'h16:	 r22<=  wskd_r22;
			7'h17:	 r23<=  wskd_r23;
			7'h18:	 r24<=  wskd_r24;
			7'h19:	 r25<=  wskd_r25;
			7'h1A:	 r26<=  wskd_r26;
			7'h1B:	 r27<=  wskd_r27;
			7'h1C:	 r28<=  wskd_r28;
			7'h1D:	 r29<=  wskd_r29;
			7'h1E:	 r30<=  wskd_r30;
			7'h1F:	 r31<=  wskd_r31;
			7'h20:	 r32<=  wskd_r32;
			7'h21:	 r33<=  wskd_r33;
			7'h22:	 r34<=  wskd_r34;
			7'h23:	 r35<=  wskd_r35;
			7'h24:	 r36<=  wskd_r36;
			7'h25:	 r37<=  wskd_r37;
			7'h26:	 r38<=  wskd_r38;
			7'h27:	 r39<=  wskd_r39;
			7'h28:	 r40<=  wskd_r40;
			7'h29:	 r41<=  wskd_r41;
			7'h2A:	 r42<=  wskd_r42;
			7'h2B:	 r43<=  wskd_r43;
			7'h2C:	 r44<=  wskd_r44;
			7'h2D:	 r45<=  wskd_r45;
			7'h2E:	 r46<=  wskd_r46;
			7'h2F:	 r47<=  wskd_r47;
			7'h30:	 r48<=  wskd_r48;
			7'h31:	 r49<=  wskd_r49;
			7'h32:	 r50<=  wskd_r50;
			7'h33:	 r51<=  wskd_r51;
			7'h34:	 r52<=  wskd_r52;
			7'h35:	 r53<=  wskd_r53;
			7'h36:	 r54<=  wskd_r54;
			7'h37:	 r55<=  wskd_r55;
			7'h38:	 r56<=  wskd_r56;
			7'h39:	 r57<=  wskd_r57;
			7'h3A:	 r58<=  wskd_r58;
			7'h3B:	 r59<=  wskd_r59;
			7'h3C:	 r60<=  wskd_r60;
			7'h3D:	 r61<=  wskd_r61;
			7'h3E:	 r62<=  wskd_r62;
			7'h3F:	 r63<=  wskd_r63;
		default: r0 <= wskd_r0;
		endcase
	end else
	begin
	 
	 /*     hash core reset signal */
	  if (r63[0]== 1'b1)begin
	   r63[0]<=1'b0;
	   hrst<=0;
	   end else
	   hrst<=1;
	 
	
	 
	 
	 
	  if (GoodNonceFound == 1'b1) begin 
       /*    if interrupt enabled generate interrupt */   
       if (r62[0]== 1'b1)begin
          nonce<=NonceOut;
          interrupt<=1'b1;
       end
    end 
   
   /*    reset interrupt signal on ack  */       
   if (r62[0]== 1'b1)begin
    if (interuptZeroAck==1'b1)
      interrupt<=1'b0;	
	end
    end 

	initial	axil_read_data = 0;
	always @(posedge S_AXI_ACLK)
	if (OPT_LOWPOWER && !S_AXI_ARESETN)
		axil_read_data <= 0;
	else if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		case(arskd_addr)
			7'h00:	axil_read_data <= r0;
			7'h01:	axil_read_data <= r1;
			7'h02:	axil_read_data <= r2;
			7'h03:	axil_read_data <= r3;
			7'h04:	axil_read_data <= r4;
			7'h05:	axil_read_data <= r5;
			7'h06:	axil_read_data <= r6;
			7'h07:	axil_read_data <= r7;
			7'h08:	axil_read_data <= r8;
			7'h09:	axil_read_data <= r9;
			7'h0A:	axil_read_data <= r10;
			7'h0B:	axil_read_data <= r11;
			7'h0C:	axil_read_data <= r12;
			7'h0D:	axil_read_data <= r13;
			7'h0E:	axil_read_data <= r14;
			7'h0F:	axil_read_data <= r15;
			7'h10:	axil_read_data <= r16;
			7'h11:	axil_read_data <= r17;
			7'h12:	axil_read_data <= r18;
			7'h13:	axil_read_data <= r19;
			7'h14:	axil_read_data <= r20;
			7'h15:	axil_read_data <= r21;
			7'h16:	axil_read_data <= r22;
			7'h17:	axil_read_data <= r23;
			7'h18:	axil_read_data <= r24;
			7'h19:	axil_read_data <= r25;
			7'h1A:	axil_read_data <= r26;
			7'h1B:	axil_read_data <= r27;
			7'h1C:	axil_read_data <= r28;
			7'h1D:	axil_read_data <= r29;
			7'h1E:	axil_read_data <= r30;
			7'h1F:	axil_read_data <= r31;
			7'h20:	axil_read_data <= r32;
			7'h21:	axil_read_data <= r33;
			7'h22:	axil_read_data <= r34;
			7'h23:	axil_read_data <= r35;
			7'h24:	axil_read_data <= r36;
			7'h25:	axil_read_data <= r37;
			7'h26:	axil_read_data <= r38;
			7'h27:	axil_read_data <= r39;
			7'h28:	axil_read_data <= r40;
			7'h29:	axil_read_data <= r41;
			7'h2A:	axil_read_data <= r42;
			7'h2B:	axil_read_data <= r43;
			7'h2C:	axil_read_data <= r44;
			7'h2D:	axil_read_data <= r45;
			7'h2E:	axil_read_data <= r46;
			7'h2F:	axil_read_data <= r47;
			7'h30:	axil_read_data <= r48;
			7'h31:	axil_read_data <= r49;
			7'h32:	axil_read_data <= r50;
			7'h33:	axil_read_data <= r51;
			7'h34:	axil_read_data <= r52;
			7'h35:	axil_read_data <= r53;
			7'h36:	axil_read_data <= r54;
			7'h37:	axil_read_data <= r55;
			7'h38:	axil_read_data <= r56;
			7'h39:	axil_read_data <= r57;
			7'h3A:	axil_read_data <= r58;
			7'h3B:	axil_read_data <= r59;
			7'h3C:	axil_read_data <= r60;
			7'h3D:	axil_read_data <= r61;
			7'h3E:	axil_read_data <= r62;
			7'h3F:	axil_read_data <= r63;
		default: axil_read_data	<= r0;
		endcase

		if (OPT_LOWPOWER && !axil_read_ready)
			axil_read_data <= 0;
	end

	function [C_AXI_DATA_WIDTH-1:0]	apply_wstrb;
		input	[C_AXI_DATA_WIDTH-1:0]		prior_data;
		input	[C_AXI_DATA_WIDTH-1:0]		new_data;
		input	[C_AXI_DATA_WIDTH/8-1:0]	wstrb;

		integer	k;
		for(k=0; k<C_AXI_DATA_WIDTH/8; k=k+1)
		begin
			apply_wstrb[k*8 +: 8]
				= wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
		end
	endfunction







endmodule
