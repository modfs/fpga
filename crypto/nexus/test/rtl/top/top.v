`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2021, Modfs https://github.com/modfs
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////


module top(
input wire clk_p,
input wire clk_n,
output wire o_uart_tx,
input wire  i_uart_rx
    );
    
 //wire o_uart_tx=0;
 //wire  i_uart_rx =0;  
//AXI 
parameter	C_AXI_ADDR_WIDTH = 32;
parameter	C_AXI_DATA_WIDTH = 32;  
parameter	M_AXI_ADDR_WIDTH = 9;

    
wire					S_AXI_ACLK;
reg					S_AXI_ARESETN=0;
reg [2:0]   res_count=0;

wire					S_AXI_AWVALID;
wire					S_AXI_AWREADY;
wire	[C_AXI_ADDR_WIDTH-1:0]		M_AXI_AWADDR;
wire	[2:0]				S_AXI_AWPROT;

wire					S_AXI_WVALID;
wire					S_AXI_WREADY;
wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_WDATA;
wire	[C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB;

wire					S_AXI_BVALID;
wire					S_AXI_BREADY;
wire	[1:0]				S_AXI_BRESP;

wire					S_AXI_ARVALID;
wire					S_AXI_ARREADY;
wire	[C_AXI_ADDR_WIDTH-1:0]		M_AXI_ARADDR;
wire	[2:0]				S_AXI_ARPROT;

wire					S_AXI_RVALID;
wire					S_AXI_RREADY;
wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_RDATA;
wire	[1:0]				S_AXI_RRESP;   
    

wire		i_clk,hash_clk;

wire [3:0] interrupts;
wire [63:0] interuptZeroData;
wire interuptZeroAck;

wire	[M_AXI_ADDR_WIDTH-1:0]		S_AXI_ARADDR;
wire	[M_AXI_ADDR_WIDTH-1:0]		S_AXI_AWADDR;


assign S_AXI_AWADDR=  M_AXI_AWADDR[M_AXI_ADDR_WIDTH-1:0];
assign S_AXI_ARADDR=  M_AXI_ARADDR[M_AXI_ADDR_WIDTH-1:0];



reg [63:0] NonceOut;
reg GoodNonceFound;
wire nHashRst;
wire [1727:0] WorkPkt; 
wire [63:0] InNonce;
wire [63:0] target;
wire [63:0] NonceOuts;
wire [63:0] NonceOuts2;
wire GoodNonceFounds,GoodNonceFounds2;




clk_wiz_0 clk_wiz_mmcm (
  .i_clk ( i_clk    ),
   .hash_clk ( hash_clk    ),
  .clk_in1_p  ( clk_p ),
  .clk_in1_n  ( clk_n )
);



	


assign S_AXI_ACLK=i_clk;

sqrl_uart2axi master_axi(S_AXI_ACLK,i_uart_rx,o_uart_tx,
S_AXI_ARESETN,
M_AXI_AWADDR,
S_AXI_AWPROT,
S_AXI_AWVALID,
S_AXI_AWREADY,
S_AXI_WDATA,
S_AXI_WSTRB,
S_AXI_WVALID,
S_AXI_WREADY,
S_AXI_BRESP,
S_AXI_BVALID,
S_AXI_BREADY,
M_AXI_ARADDR,
S_AXI_ARPROT,
S_AXI_ARVALID,
S_AXI_ARREADY,
S_AXI_RDATA,
S_AXI_RRESP,
S_AXI_RVALID,
S_AXI_RREADY,
interrupts,
interuptZeroData,
interuptZeroAck
);


miner_saxil miner_saxil(S_AXI_ACLK,
S_AXI_ARESETN,
S_AXI_AWVALID,
S_AXI_AWREADY,
S_AXI_AWADDR,
S_AXI_AWPROT,
S_AXI_WVALID,
S_AXI_WREADY,
S_AXI_WDATA,
S_AXI_WSTRB,
S_AXI_BVALID,
S_AXI_BREADY,
S_AXI_BRESP,
S_AXI_ARVALID,
S_AXI_ARREADY,
S_AXI_ARADDR,
S_AXI_ARPROT,
S_AXI_RVALID,
S_AXI_RREADY,
S_AXI_RDATA,
S_AXI_RRESP,
interrupts,
interuptZeroData,
interuptZeroAck,
GoodNonceFound,
NonceOut,
nHashRst,
WorkPkt,
InNonce,
target
);



NexusHashTransform #(.COREIDX(0))  Nexus(NonceOuts,GoodNonceFounds,hash_clk,nHashRst,WorkPkt,InNonce,target,S_AXI_ACLK);
NexusHashTransform #(.COREIDX(1)) Nexus2(NonceOuts2,GoodNonceFounds2,hash_clk,nHashRst,WorkPkt,InNonce,target,S_AXI_ACLK);


always @(posedge S_AXI_ACLK)
begin
if (S_AXI_ARESETN == 1'b0 && res_count== 3'b111)
begin
S_AXI_ARESETN <= 1'b1;
res_count<=3'b000;
end  else res_count<=res_count+1;

if (GoodNonceFounds== 1'b1)
begin
GoodNonceFound <= GoodNonceFounds;
NonceOut <=NonceOuts ; 
end else if (GoodNonceFounds2)begin
GoodNonceFound <= GoodNonceFounds2;
NonceOut <=NonceOuts2 ; 
end else
GoodNonceFound <= 1'b0;
end


endmodule
