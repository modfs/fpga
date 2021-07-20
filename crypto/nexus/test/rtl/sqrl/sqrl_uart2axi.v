// v1.0.0 Official
module sqrl_uart2axi #(
    parameter CLK_RATE = 100000000,
    parameter BAUD_RATE = 1000000,
    parameter USE_JTAG = 0
  ) (
  input clk,
  input uart_rx,
  output uart_tx,
 
  // AXI-Lite, 64 bit in uart protocol, can drive 32 as needed 
  // AXI clk is the same as uart "driving" clock - 100 MHz
  //input axi_clk,
  input axi_resetn,
  
  output wire [31:0] axi_awaddr,
  output wire [2:0] axi_awprot,
  output wire axi_awvalid,
  input wire axi_awready,

  output wire [31:0] axi_wdata, 
  output wire [(32/8)-1:0] axi_wstrb,
  output wire axi_wvalid,
  input wire axi_wready,

  input [1:0] axi_bresp,
  input axi_bvalid,
  output axi_bready,

  output wire [31:0] axi_araddr, 
  output wire [2:0] axi_arprot,
  output wire axi_arvalid,
  input wire axi_arready,

  input wire [31:0] axi_rdata,
  input wire [1:0] axi_rresp,
  input wire axi_rvalid,
  output wire axi_rready,
  
  // Interrupt support - Allows  
  input wire [3:0] interrupts,
  input wire [63:0] interuptZeroData,
  output reg interuptZeroAck
);

localparam CRC32POL = 32'hEDB88320;

function [31:0] genCRC32;
  input [31:0] curCRC, word;
  begin : crc32
    integer j;
    reg [7:0] mybyte;
    mybyte = word[31:24];
    for(j = 0; j <8; j=j+1)
    begin
      if ((curCRC[0]) != (mybyte[0])) begin
        curCRC = (curCRC >> 1) ^ CRC32POL;
      end else begin
        curCRC = (curCRC >> 1);
      end
      mybyte = mybyte >> 1;
    end
    mybyte = word[23:16];
    for(j = 0; j <8; j=j+1)
    begin
      if ((curCRC[0]) != (mybyte[0])) begin
        curCRC = (curCRC >> 1) ^ CRC32POL;
      end else begin
        curCRC = (curCRC >> 1);
      end
      mybyte = mybyte >> 1;
    end
    mybyte = word[15:8];
    for(j = 0; j <8; j=j+1)
    begin
      if ((curCRC[0]) != (mybyte[0])) begin
        curCRC = (curCRC >> 1) ^ CRC32POL;
      end else begin
        curCRC = (curCRC >> 1);
      end
      mybyte = mybyte >> 1;
    end
    mybyte = word[7:0];
    for(j = 0; j <8; j=j+1)
    begin
      if ((curCRC[0]) != (mybyte[0])) begin
        curCRC = (curCRC >> 1) ^ CRC32POL;
      end else begin
        curCRC = (curCRC >> 1);
      end
      mybyte = mybyte >> 1;
    end

    genCRC32 = curCRC;
  end
endfunction

genvar j;

// Internal Architecture:
// 1. UART messages  are CMD(1 Byte)SEQ(1 Byte)ADDR(8bytes BE)DATA(4bytes BE, 0 on read)CRC(2 BYTE)
// 2. UART responses are RESP(1 BytE)SEQ(1 byte, echo)ADDR(8byte BE, echo)(DATA(4 bytes BE)CRC(2 BYTE)

// AXI Queue can hold exactly 1 message. AXI expected to be much faster than UART, but an appropriate 
//  response will be issued if it is busy 
//
//  Addendum: The addition of "jtag2uart" support as a driver, when present,
//  will disable the uart_rx/uart_tx pins and drive packets directly 

wire jtag_uart_rx = 1'b0;
wire int_uart_tx;

wire int_uart_rx = (USE_JTAG?jtag_uart_rx:uart_rx);
assign uart_tx = (USE_JTAG?1'b0:int_uart_tx);
wire jtag_uart_tx = (USE_JTAG?int_uart_tx:1'b0);

// UART Bit Engine:
reg [7:0] rxBitReg;
reg [7:0] rxBitRegBitValid;

wire [7:0] int_rx_byte;
wire [7:0] rx_byte;
wire int_rx_byte_valid;
wire rx_byte_valid;

generate
for(j=0; j < (USE_JTAG?0:1); j=j+1)
begin : UART_RX_LOOP 
  sqrl_uart_recv #(
    .comm_clk_frequency(CLK_RATE),
    .baud_rate(BAUD_RATE)
  ) uart_rx_1 (
    .clk(clk),
    .uart_rx(int_uart_rx),
    .rx_byte(int_rx_byte),
    .rx_new_byte(int_rx_byte_valid) 
  );
end
endgenerate

wire rxBit = rxBitReg[7];
wire rxBitValid = rxBitRegBitValid[7]; 
wire rxByteEnd = rxBitValid & (rxBitRegBitValid[6] == 1'b0);
reg rxByteEnd_delay = 1'b0;
always @(posedge clk)
begin
  if (axi_resetn == 1'b0) 
  begin
    rxBitRegBitValid <= 8'h00;
    rxByteEnd_delay <= 1'b0;
  end else begin
    rxByteEnd_delay <= rxByteEnd;
    if (rx_byte_valid)
    begin
      // This can only happen every 8 cycles
      rxBitReg[7:0] <= rx_byte[7:0];
      rxBitRegBitValid[7:0] <= 8'hFF;
    end else begin
      rxBitReg[7:0] <= {rxBitReg[6:0], 1'b0};
      rxBitRegBitValid[7:0] <= {rxBitRegBitValid[6:0], 1'b0};
    end
  end
end

// TX Engine
wire int_tx_ready;
reg [7:0] tx_byte;
reg tx_byte_ready = 1'b0;

generate
for(j=0; j < (USE_JTAG?0:1); j=j+1)
begin : UART_TX_LOOP 
  sqrl_uart_xmit # (
    .comm_clk_frequency(CLK_RATE),
    .baud_rate(BAUD_RATE)
  ) uart_tx_1 (
    .clk(clk),
    .uart_tx(int_uart_tx),
    .tx_ready(int_tx_ready),
    .tx_byte(USE_JTAG?8'd0:tx_byte),
    .tx_new_byte(USE_JTAG?0:tx_byte_ready)
  );
end
endgenerate

// JTAG - If JTAG mode, drive bytes from jtag
wire [7:0] jtag_rxByte;
wire jtag_rxByteValid;
assign rx_byte = (USE_JTAG?jtag_rxByte:int_rx_byte);
assign rx_byte_valid = (USE_JTAG?jtag_rxByteValid:int_rx_byte_valid);
wire [7:0] jtag_txByte = (USE_JTAG?tx_byte:8'd0);
wire jtag_txByteValid = (USE_JTAG?tx_byte_ready:0);
wire jtag_txByteReady;
wire tx_ready = (USE_JTAG?jtag_txByteReady:int_tx_ready); 

generate
for(j=0; j < USE_JTAG; j=j+1)
begin : JTAG_LOOP
  sqrl_jtag_uart engine (
    .clk(clk),
    .rstn(axi_resetn),
    .rxByte(jtag_rxByte),
    .rxValid(jtag_rxByteValid),
    .txByte(jtag_txByte),
    .txValid(jtag_txByteValid),
    .txReady(jtag_txByteReady)
  );
end

endgenerate

// TX CRC Variables
reg [15:0] txCRC;

// TX Message Buffer
reg [111:0] nextTxMsg;
reg nextTxMsgValid;

reg [127:0] txMsg;
reg [15:0] txByteValid;

wire nextTxMsgAck = (txByteValid[15] == 0);

always @(posedge clk)
begin
  if (axi_resetn == 1'b0)
  begin
    txByteValid <= 16'd0; 
  end else begin 
    if (txByteValid[15] && tx_ready)
    begin
      if (txByteValid[14] == 1'b0)
      begin
          // Message is now the last byte of CRC!
          tx_byte <= txCRC[7:0];
      end else if (txByteValid[13] == 1'b0)
      begin
          tx_byte <= txCRC[15:8];
      end else begin
          txMsg[127:0] <= {txMsg[119:0], 8'd0};
          tx_byte <= txMsg[127:120];
      end
      txByteValid[15:0] <= {txByteValid[14:0], 1'b0};
      tx_byte_ready <= 1'b1;
    end else begin
      tx_byte_ready <= 1'b0;

      if ( nextTxMsgValid && txByteValid[15] == 1'b0)
      begin
        txByteValid[15:0] <= 16'hFFFF;
        // CRC should be calculated during transmission
        txMsg[127:0] <= {nextTxMsg[111:0], 16'h0000/*CRC TODO*/};
      end
    end
  end
end

reg [2:0] crcState;
always @(posedge clk)
begin
  if (axi_resetn == 1'b0)
  begin
    crcState <= 3'b000;
  end else begin
    if (crcState == 3'b000)
    begin
      if (txByteValid[0] == 1'b1)
      begin
        // This is the start of a new CRC, it hasn't been 
        // picked up for transmission yet
        txCRC <= ((16'hFFFF ^ {8'h00,txMsg[127:120]}) >> 1) ^ (txMsg[120]?16'h0000:16'hA001);
        if (tx_ready)
        begin
          crcState <= 3'b001;
        end else begin
          crcState <= crcState;
        end
      end else if (txByteValid[13] & tx_ready)
      begin
        // Roll in the start of the new byte if we aren't to the end
        txCRC <= ((txCRC ^ {8'h00,txMsg[127:120]}) >> 1) ^ ((txMsg[120]^txCRC[0])?16'hA001:16'h0000);
        crcState <= 3'b001;
      end else begin
        crcState <= crcState;
      end
    end else begin
      // Process bits - it takes minimum 8 cycles, so we have time
      txCRC <= (txCRC[0] ? ((txCRC >> 1) ^ 16'hA001) : (txCRC >> 1));
      crcState[2:0] <= crcState[2:0] + 1;
    end

  end
end

// RX bit counter
reg [127:0] rxBuf; // 128 are bits received while computing CRC

// Continually Computing CRC
reg [15:0] crcPipe[128:0];

wire [111:0] rxMsg;
assign rxMsg[111:0] = rxBuf[127:16];

// Framing
reg [3:0] framePos;
always @(posedge clk)
begin
  if(axi_resetn == 1'b0)
  begin
    framePos <= 4'd0;
  end else if (rxByteEnd_delay == 1'b1) begin
    if ((framePos == 4'd15) && (rxBuf[15:0] != crcPipe[121])) 
    begin
      framePos <= 4'd15;// Stay at framepos 0 while CRC is not valid (re-synching)
    end begin
      framePos <= framePos + 4'd1; // Increment framepos
    end
  end
end


wire crcValid;
assign crcValid = ((framePos == 4'd15) && (rxByteEnd_delay == 1'b1));

// RX Engine
always @(posedge clk)
begin 
  if (rxBitValid && axi_resetn == 1'b1)
  begin
    rxBuf[127:0] <= {rxBuf[126:0], rxBit};
  end 
end

// CRC Engine
integer i;
always @(posedge clk) 
begin
  if (rxBitValid)
  begin
    crcPipe[0] <= 16'hFFFF;
    crcPipe[1] <= ((crcPipe[0] ^ {rxBuf[6:0], rxBit}) >> 1) ^ ((rxBit == 1'b0)?16'hA001:16'h0000);
    crcPipe[2] <= crcPipe[1][0] ? ((crcPipe[1] >> 1) ^ 16'hA001) : (crcPipe[1] >> 1); 
    crcPipe[3] <= crcPipe[2][0] ? ((crcPipe[2] >> 1) ^ 16'hA001) : (crcPipe[2] >> 1); 
    crcPipe[4] <= crcPipe[3][0] ? ((crcPipe[3] >> 1) ^ 16'hA001) : (crcPipe[3] >> 1); 
    crcPipe[5] <= crcPipe[4][0] ? ((crcPipe[4] >> 1) ^ 16'hA001) : (crcPipe[4] >> 1); 
    crcPipe[6] <= crcPipe[5][0] ? ((crcPipe[5] >> 1) ^ 16'hA001) : (crcPipe[5] >> 1); 
    crcPipe[7] <= crcPipe[6][0] ? ((crcPipe[6] >> 1) ^ 16'hA001) : (crcPipe[6] >> 1); 
    crcPipe[8] <= crcPipe[7][0] ? ((crcPipe[7] >> 1) ^ 16'hA001) : (crcPipe[7] >> 1); 
    crcPipe[9] <= ((crcPipe[8] ^ {rxBuf[6:0], rxBit}) >> 1) ^ ((crcPipe[8][0] ^ rxBit) ? 16'hA001 : 16'h0000);

      for ( i = 8; i <= 104; i = i + 8) begin: crc_pipe    
        crcPipe[2+i] <= crcPipe[1+i][0] ? ((crcPipe[1+i] >> 1) ^ 16'hA001) : (crcPipe[1+i] >> 1); 
        crcPipe[3+i] <= crcPipe[2+i][0] ? ((crcPipe[2+i] >> 1) ^ 16'hA001) : (crcPipe[2+i] >> 1); 
        crcPipe[4+i] <= crcPipe[3+i][0] ? ((crcPipe[3+i] >> 1) ^ 16'hA001) : (crcPipe[3+i] >> 1); 
        crcPipe[5+i] <= crcPipe[4+i][0] ? ((crcPipe[4+i] >> 1) ^ 16'hA001) : (crcPipe[4+i] >> 1); 
        crcPipe[6+i] <= crcPipe[5+i][0] ? ((crcPipe[5+i] >> 1) ^ 16'hA001) : (crcPipe[5+i] >> 1); 
        crcPipe[7+i] <= crcPipe[6+i][0] ? ((crcPipe[6+i] >> 1) ^ 16'hA001) : (crcPipe[6+i] >> 1); 
        crcPipe[8+i] <= crcPipe[7+i][0] ? ((crcPipe[7+i] >> 1) ^ 16'hA001) : (crcPipe[7+i] >> 1); 
        if (i != 104)
          crcPipe[9+i] <= ((crcPipe[8+i] ^ {rxBuf[6:0], rxBit}) >> 1) ^ ((crcPipe[8+i][0] ^ rxBit) ? 16'hA001 : 16'h0000);
      end
     for( i = 112; i < 128; i = i + 1)
     begin
       crcPipe[i+1] <= crcPipe[i];
     end
  end
end

reg [63:0] axiReadAddr;
reg [7:0] axiReadSeq;
reg [31:0] axiReadData;
reg [1:0] axiReadResp;
reg [7:0] axiReadRespSeq;
reg [63:0] axiReadRespAddr;
reg [31:0] axiWriteRespData;
reg axiReadReqValid;
reg axiReadRespValid = 1'b0;

reg [63:0] axiWriteAddr;
reg [7:0] axiWriteSeq;
reg [31:0] axiWriteData;
reg [1:0] axiWriteResp;
reg [7:0] axiWriteRespSeq;
reg [63:0] axiWriteRespAddr;
reg axiWriteReqValid;
reg axiWriteAddrAck = 1'b0;
reg axiWriteDataAck = 1'b0;
reg axiWriteRespValid = 1'b0;

assign axi_rready = (axiReadRespValid == 1'b0);
assign axi_bready = (axiWriteRespValid == 1'b0);

assign axi_awvalid = (axiWriteReqValid == 1'b1 && axiWriteAddrAck == 1'b0);
assign axi_wvalid = (axiWriteReqValid == 1'b1 && axiWriteDataAck == 1'b0);

assign axi_arvalid = (axiReadReqValid == 1'b1);

assign axi_awaddr[31:0] = axiWriteAddr[31:0]; // NOTE: Truncated!
assign axi_awprot[2:0] = 3'b001; // IntelFPGA Requires
assign axi_wdata[31:0] = axiWriteData[31:0];
assign axi_wstrb[3:0] = 4'b1111; // NO STROBE SUPPORT

assign axi_araddr[31:0] = axiReadAddr[31:0]; // NOTE: Truncated!
assign axi_arprot[2:0] = 3'b001; // IntelFPGA Requires

// Bulk Mode
reg bulkMode = 1'b0;
reg bulkWrite = 1'b0;
reg [3:0] bulkPhase;
reg [31:0] bulkCounter;
reg [31:0] bulkRxCounter;
reg [63:0] bulkAddress;

reg [31:0] bulkCRC32;

reg pendingInterrupt = 0;
reg [3:0] pendingInterrupts;
reg [63:0] pendingIntData;
reg [7:0] intrSeq;

// Begin actual message processing
always @(posedge clk) 
begin
  if (axi_resetn == 1'b0)
  begin
    pendingInterrupt <= 0;
    pendingInterrupts <= 0;
    pendingIntData <= 0;
    interuptZeroAck <= 0;
    intrSeq <= 0;
    axiReadReqValid <= 1'b0;
    axiWriteReqValid <= 1'b0;
    axiWriteAddrAck <= 1'b0;
    axiWriteDataAck <= 1'b0;
    axiReadRespValid <= 1'b0;
    axiWriteRespValid <= 1'b0;
    nextTxMsgValid <= 1'b0;
    bulkMode <= 1'b0;
    bulkWrite <= 1'b0;
    bulkCounter <= 32'd0;
  end else begin
  // We deal with:
  // Inbound messages (every cycle)
  // reg [111:0] rxMsg;
  // wire crcValid (If this message can be processed

  // Outbound message  - generate or clearValid flag if ack'd
  // reg [111:0] nextTxMsg;
  // reg nextTxMsgValid;
  // wire nextTxMsgAck = (tsByteValid[7] == 0);

  // AXI Read Resp 
  if (axi_rvalid & axi_rready)
  begin
    // We have an AXI read response, accept and store
    axiReadRespValid <= 1'b1;
    axiReadData <= axi_rdata;
    axiReadResp <= axi_rresp;
  end else begin
    if (axiReadRespValid && ( nextTxMsgAck || nextTxMsgValid == 1'b0) )
    begin
      axiReadRespValid <= 1'b0;
      nextTxMsg[111:0] <= {axiReadResp[1:0],6'h01, axiReadRespSeq[7:0], axiReadRespAddr[63:0], axiReadData[31:0]}; 
      nextTxMsgValid <= 1'b1;
    end
  end

  // AXI Write Resp
  if (axi_bvalid & axi_bready)
  begin
    // We have an AXI write response, accept and store
    axiWriteRespValid <= 1'b1;
    axiWriteResp <= axi_bresp;
  end else begin
    if (bulkMode && bulkWrite)
    begin
      if (axiWriteRespValid && ( nextTxMsgAck || nextTxMsgValid == 1'b0) )
      begin
        if (axiWriteResp != 2'b00)
        begin
          // Return immediately on failure
          axiWriteRespValid <= 1'b0;
          nextTxMsg[111:0] <= {axiWriteResp[1:0], 6'h02, axiWriteRespSeq[7:0], axiWriteRespAddr[63:0], axiWriteRespData[31:0]};
          nextTxMsgValid <= 1'b1;
          bulkMode <= 1'b0;
        end else if (bulkRxCounter[31:0] == 32'd4)
        begin
          // Responsd to a complete write (WriteRespData should be CRC32 of all data written)
          axiWriteRespValid <= 1'b0;
          nextTxMsg[111:0] <= {axiWriteResp[1:0], 6'h02, axiWriteRespSeq[7:0], axiWriteRespAddr[63:0], 32'hFFFFFFFF ^ bulkCRC32[31:0]};
          nextTxMsgValid <= 1'b1;
          bulkMode <= 1'b0;
        end else begin
          bulkRxCounter[31:0] <= bulkRxCounter[31:0] - 32'd4;
          axiWriteRespValid <= 1'b0;
        end
      end
    end else begin
      if (axiWriteRespValid && ( nextTxMsgAck || nextTxMsgValid == 1'b0) )
      begin
        axiWriteRespValid <= 1'b0;
        nextTxMsg[111:0] <= {axiWriteResp[1:0], 6'h02, axiWriteRespSeq[7:0], axiWriteRespAddr[63:0], axiWriteRespData[31:0]};
        nextTxMsgValid <= 1'b1;
      end
    end
  end

  // Handle AXI bus accepting read
  if (axi_arvalid & axi_arready)
  begin
    axiReadRespSeq <= axiReadSeq;
    axiReadRespAddr <= axiReadAddr;
    axiReadReqValid <= 1'b0;
  end 

  // Handle AXI bus accepting write address (before or after data)
  if (axi_awvalid & axi_awready)
  begin
    axiWriteReqValid <= ((axiWriteDataAck == 1'b1) || (axi_wvalid & axi_wready))?1'b0:1'b1;
    axiWriteRespSeq <= axiWriteSeq;
    axiWriteRespData <= axiWriteData;
    axiWriteRespAddr <= axiWriteAddr;
    axiWriteAddrAck <= 1'b1;
  end 
 
  // Handle AXI bus accepting write data (before or after address)
  if (axi_wvalid && axi_wready)
  begin
    axiWriteReqValid <= ((axiWriteAddrAck == 1'b1) || (axi_awvalid & axi_awready))?1'b0:1'b1;
    axiWriteRespSeq <= axiWriteSeq;
    axiWriteRespData <= axiWriteData;
    axiWriteRespAddr <= axiWriteAddr;
    axiWriteDataAck <= 1'b1;
  end

  if (nextTxMsgAck & nextTxMsgValid)
  begin
    nextTxMsgValid <= 1'b0;
  end
  
  // Interrupt Handling
  if (interrupts != 4'b0000)
  begin
    // Store the pending interrupt!
    if (pendingInterrupt == 0)
    begin
      pendingInterrupt <= 1'b1;
      pendingInterrupts <= interrupts;
      pendingIntData <= interuptZeroData;
      interuptZeroAck <= 1;
    end else begin
      interuptZeroAck <= 0;
    end
  end else begin
    interuptZeroAck <= 0;
  end
  if (pendingInterrupt & (nextTxMsgValid == 1'b0 || nextTxMsgAck) & ~crcValid)
  begin
    // We are clear to issue the interrupt
    pendingInterrupt <= 0;
    nextTxMsgValid <= 1'b1;
    nextTxMsg[111:0] <= {pendingInterrupts[3:0],4'h7, intrSeq[7:0] , (pendingInterrupts[0]?pendingIntData[63:0]:64'd0), 32'h00000000};
    intrSeq <= intrSeq +1;
  end 

  // Inbound Message?
  if (crcValid && bulkMode == 1'b0)
  begin
    // Check command
    // CMD: rxMsg[111:104]
    // SEQ: rxMsg[103:96]
    // ADDR: rxMsg[95:32]
    // DATA: rxMsg[31:0]
    // CMD 0 - NOP, RESPOND DEADCAFE // Zombies!
    // CMD 1 - AXI Read
    // CMD 2 - AXI Write
    // Upper 2 bits of CMD are flags, only read and write support (otherwise ignored)
    // 00 - Normal
    // 01 - BULK (Data field is length - MUST be multiple of 16) - next (length >> 4) packets (ignore CRC) are
    //    - raw data
    // RESP 0 - NOP/ACK
    // RESP 1 - Read Resp (upper 2 bits are AXI response code! - bit 5 is timeout, 4 is internal invalid addr, 3 == busy)
    // RESP 2 - Write Resp (upper 2 bits are AXI response code! - bit 5 is timeout, 4 is internal invalid addr, 3 == busy)
    // RESP 3 - ERROR (Could double as interrupt with flag bits)
    if (rxMsg[109:104] == 6'h00)
    begin
      if (nextTxMsgValid == 1'b0 || nextTxMsgAck) 
      begin
        nextTxMsg[111:0] <= {8'h00, rxMsg[103:96], 64'hDEADCAFE12345678, 32'h00000001};
        nextTxMsgValid <= 1'b1;
      end else begin
        // BUSY! - this shouldn't happen!
      end
    end else if (rxMsg[109:104] == 6'h01) begin
      // READ!
      if (axiReadReqValid == 1'b1)
      begin
        // Send immediate failure! (BUSY)
        if (nextTxMsgValid == 1'b0 || nextTxMsgAck)
        begin
          nextTxMsg[111:0] <= {8'h09, rxMsg[103:96], rxMsg[95:32], 32'h00000000};
          nextTxMsgValid <= 1'b1;
        end else begin
          // BUSY! - this shouldn't happen!
        end
      end else begin
        // Place it in queue
        axiReadReqValid <= 1'b1;
        axiReadAddr <= rxMsg[95:32];
        axiReadSeq <= rxMsg[103:96]; 
      end
    end else if (rxMsg[109:104] == 6'h02) begin
      if (rxMsg[110] == 1'b1)
      begin
        // Enter BULK mode and set the counter
        bulkMode <= 1'b1;
        bulkWrite <= 1'b1;
        bulkPhase <= 4'b0000;
        bulkCounter <= rxMsg[31:0];
        bulkRxCounter <= rxMsg[31:0];
        bulkAddress <= rxMsg[95:32];
        bulkCRC32 <= 32'hFFFFFFFF;
        axiWriteSeq <= rxMsg[103:96]; 
      end else begin
        if (axiWriteReqValid == 1'b1)
        begin
          // Send immediate failure! (BUSY)
          if (nextTxMsgValid == 1'b0 || nextTxMsgAck)
          begin
            nextTxMsg[111:0] <= {8'h0A, rxMsg[103:96], rxMsg[95:32], rxMsg[31:0]};
            nextTxMsgValid <= 1'b1;
          end else begin
            // BUSY! - this shouldn't happen!
          end
        end else begin
          // Place it in queue
          axiWriteReqValid <= 1'b1;
          axiWriteDataAck <= 1'b0;
          axiWriteAddrAck <= 1'b0;
          axiWriteAddr <= rxMsg[95:32];
          axiWriteData <= rxMsg[31:0];
          axiWriteSeq <= rxMsg[103:96]; 
        end
      end
    end else begin
      // INVALID!
      if (nextTxMsgValid == 1'b0 || nextTxMsgAck) 
      begin
        nextTxMsg[111:0] <= {8'h03, rxMsg[103:96], 64'h10BAD0BAD00DAD00, 32'hFFFFFFFF};
        nextTxMsgValid <= 1'b1;
      end else begin
        // BUSY! - this shouldn't happen!
      end
    end
  end else if (bulkMode && bulkWrite)
    begin
      // If we're on a word boundary, write it!
      if (rxByteEnd_delay)
      begin
        
        if (( bulkPhase[3:0] == 4'd3 || bulkPhase[3:0] == 4'd7 ||
              bulkPhase[3:0] == 4'd11 || bulkPhase[3:0] == 4'd15 ) &&
              (bulkCounter[31:0] != 32'd0)
              )
        begin
          // The rxBuf is aligned to a word to write
          // TODO - This assumes the AXI bus always responds faster 
          // than it takes for the UART to queue another 32 bit. 
          // Nominally UART max speed is 1/10th of our clock, so that is minimum of 400 cycles
          // - This is a reasonable AXI Write Timeout, but we're not detecting or reporting a failure!
          
          axiWriteReqValid <= 1'b1;
          axiWriteDataAck <= 1'b0;
          axiWriteAddrAck <= 1'b0;
          axiWriteAddr <= bulkAddress[63:0];
          axiWriteData <= rxBuf[31:0];
          bulkCRC32 = genCRC32(bulkCRC32[31:0], rxBuf[31:0]);
          bulkAddress[63:0] <= bulkAddress[63:0] + 64'd4;
          bulkCounter[31:0] <= bulkCounter[31:0] - 32'd4;
        end
        bulkPhase[3:0] <= bulkPhase[3:0] + 4'd1;
      end
    end
  end 
end


endmodule
