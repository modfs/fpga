`timescale 1ns / 1ps

`define IDX64(x)            ((x) << 6)+:64

`define COMBINATORIAL_KEY_INJ		1

//`define QOR_PIPE_STAGE              1

module NexusHashTransform(output wire [63:0] ext_NonceOut, output wire ext_GoodNonceFound, input wire clk, input wire ext_nHashRst, input wire [1727:0] ext_WorkPkt, input wire [63:0] ext_InNonce,input wire [63:0] ext_target, input wire sysclk);
	
	parameter HASHERS = 1, COREIDX = 0;
	
	// Every Skein round has four clock cycles of latency, and every
	// Skein key injection has 2 clock cycles of latency. If using the
	// pipe stage for QoR, each Skein round has five clock cycles of latency.
	// If using combinatorial key injections, each key stage has one cycle
	// of latency.
	`ifdef QOR_PIPE_STAGE
	localparam SKEINRNDSTAGES = 5;
	`else
	localparam SKEINRNDSTAGES = 4;
	`endif
	
	`ifdef COMBINATORIAL_KEY_INJ
	localparam SKEINKEYSTAGES = 1;
	`else
	localparam SKEINKEYSTAGES = 2;
	`endif
	
	// Every Keccak round has two clock cycles of latency,
	// and there are 24 rounds
	localparam KECCAKRNDSTAGES = 2, KECCAKROUNDS = 24;
	
	// 20 rounds, with 21 key injections per block process
	localparam SKEINROUNDS = 20, SKEINKEYINJECTIONS = 21;
	
	// 24 rounds, round has 2 clock cycles of latency
	localparam KECCAKBLKSTAGES = KECCAKRNDSTAGES * KECCAKROUNDS;
	
	// 20 rounds, 4 clock cycles of latency per round, and 21 key
	// injections, 2 clock cycles of latency per key injection
	localparam SKEINBLKSTAGES = (SKEINRNDSTAGES * SKEINROUNDS) + (SKEINKEYINJECTIONS * SKEINKEYSTAGES);
	
	// Nexus' SK1024 proof-of-work, SK1024 (after midstate, during which
	// one Skein block process is done) consists of two Skein block processes
	// and three Keccak block processes. Add one to account for the extra
	// XOR stage in the first Skein block. Add 1 more cause I lost a pipe stage.
	localparam TOTALSTAGES = (SKEINBLKSTAGES * 2) + (KECCAKBLKSTAGES * 3) + 2;
	
	reg [63:0] NonceOut=0;
    reg GoodNonceFound=0;
    
    reg [63:0] target=0;
    reg [639:0] BlkHdrTail;
	reg [1087:0] Midstate;
	reg [63:0] CurNonce=0;
    
    wire HashRst;
    wire [1727:0] sig_WorkPkt;
    wire [63:0] sig_InNonce;
    wire [63:0] sig_target;
   

wire newTargetValid;
wire ext_target_rx;
 xpm_cdc_handshake #(
    .DEST_EXT_HSK(0),
    .DEST_SYNC_FF(4),
    .SRC_SYNC_FF(4),
    .SIM_ASSERT_CHK(1),
    .WIDTH(64)
  ) targetCDC (
    .dest_out(sig_target),
    .dest_req(newTargetValid),
    .src_rcv(ext_target_rx),
    .dest_ack(0),
    .dest_clk(clk),
    .src_clk(sysclk),
    .src_in(ext_target),
    .src_send(~ext_nHashRst)
  );

wire newnonceValid;
wire ext_nonce_rx;
 xpm_cdc_handshake #(
    .DEST_EXT_HSK(0),
    .DEST_SYNC_FF(4),
    .SRC_SYNC_FF(4),
    .SIM_ASSERT_CHK(1),
    .WIDTH(64)
  )  InNonceCDC (
    .dest_out(sig_InNonce),
    .dest_req(newnonceValid),
    .src_rcv(ext_nonce_rx),
    .dest_ack(0),
    .dest_clk(clk),
    .src_clk(sysclk),
    .src_in(ext_InNonce),
    .src_send(~ext_nHashRst)
  );

wire src_rcv_WorkPkt_high,new_WorkPkt_high_Valid;
xpm_cdc_handshake #(
  .DEST_EXT_HSK(0),
    .DEST_SYNC_FF(4),
    .SRC_SYNC_FF(4),
    .SIM_ASSERT_CHK(1),
    .WIDTH(1024)
)
xpm_cdc_handshake_WorkPkt_high (
 .dest_out(sig_WorkPkt[1727:704]), 
 .dest_req(new_WorkPkt_high_Valid), 
 .src_rcv(src_rcv_WorkPkt_high),
  .dest_ack(0),
  .dest_clk(clk),
  .src_clk(sysclk),
 .src_in(ext_WorkPkt[1727:704]), 
 .src_send(~ext_nHashRst) 
 
);


wire src_rcv_WorkPkt_low,new_WorkPkt_low_Valid;
xpm_cdc_handshake #(
  .DEST_EXT_HSK(0),
    .DEST_SYNC_FF(4),
    .SRC_SYNC_FF(4),
    .SIM_ASSERT_CHK(1),
 .WIDTH(704) 
)
xpm_cdc_handshake_WorkPkt_low (
 .dest_out(sig_WorkPkt[703:0]), 
 .dest_req(new_WorkPkt_low_Valid), 
 .src_rcv(src_rcv_WorkPkt_low),
  .dest_ack(0),
  .dest_clk(clk),
  .src_clk(sysclk),
 .src_in(ext_WorkPkt[703:0]), 
 .src_send(~ext_nHashRst) 
 
);



	
	xpm_fifo_async #(
      .CDC_SYNC_STAGES(2),       // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("auto"), // String
      .FIFO_READ_LATENCY(1),     // DECIMAL
      .FIFO_WRITE_DEPTH(16),   // DECIMAL
      .FULL_RESET_VALUE(0),      // DECIMAL
      .PROG_EMPTY_THRESH(10),    // DECIMAL
      .PROG_FULL_THRESH(10),     // DECIMAL
      .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
      .READ_DATA_WIDTH(64),      // DECIMAL
      .READ_MODE("fwft"),         // String
      .RELATED_CLOCKS(0),        // DECIMAL
      .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("1000"), // String
      .WAKEUP_TIME(0),           // DECIMAL
      .WRITE_DATA_WIDTH(64),     // DECIMAL
      .WR_DATA_COUNT_WIDTH(1)    // DECIMAL
   )
    nonce_fifo (
      .data_valid(ext_GoodNonceFound), 
      .dout(ext_NonceOut),
      .din(NonceOut),
      .injectdbiterr(1'b0),
      .injectsbiterr(1'b0),
      .rd_clk(sysclk), 
      .rd_en(1'b1),
      .rst(1'b0),
      .sleep(1'b0), 
      .wr_clk(clk),
      .wr_en(GoodNonceFound) 
   );


	
	genvar x;
		
	// Inputs
	reg [TOTALSTAGES-1:0] PipeOutputGood = 0;

		
	wire [1087:0] SkeinOutput0;
	wire [1023:0] SkeinOutput1;
	wire [63:0] KeccakOutputQword;
	
	assign HashRst=(newTargetValid && newnonceValid && new_WorkPkt_high_Valid && new_WorkPkt_low_Valid);
    
    always @(posedge clk)
	begin
		// Active-low reset pulled low, reload work
		if(HashRst)
		begin
              PipeOutputGood <= 0;
		      target<=sig_target;
	          BlkHdrTail <= sig_WorkPkt[639:0];
	          Midstate <= sig_WorkPkt[1727:640];
			if (COREIDX<2)begin
			CurNonce[63:0] <= {sig_InNonce[63:37],(sig_InNonce[36]^^COREIDX),sig_InNonce[35:0]} ;
			end else
			 begin
			 CurNonce[63:0] <= {sig_InNonce[63:38],(sig_InNonce[37]^^COREIDX),sig_InNonce[36:0]} ;
			 end
		end else
		begin
			CurNonce <= CurNonce + HASHERS;
		end
		
		PipeOutputGood <= (PipeOutputGood << 1) | ~HashRst;
		
		// Lazy target check - check for 32 bits of zero, and filter further
		// on the miner side; I am cheap and dirty
		GoodNonceFound <= PipeOutputGood[TOTALSTAGES-1] & (KeccakOutputQword < target);
		NonceOut <= CurNonce - TOTALSTAGES;
	end
	
	FirstSkeinRound   Block1ProcessTest(SkeinOutput0, clk, BlkHdrTail[639:0], Midstate, CurNonce);
	SecondSkeinRound Block2ProcessTest(SkeinOutput1, clk, SkeinOutput0);
	NexusKeccak1024   KeccakProcessTest(KeccakOutputQword, clk, SkeinOutput1);
endmodule
