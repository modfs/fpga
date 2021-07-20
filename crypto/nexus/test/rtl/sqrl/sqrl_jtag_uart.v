module  sqrl_jtag_uart (
    input clk,
    input rstn,
    output reg [7:0] rxByte = 0,
    output reg rxValid = 0,
    input [7:0] txByte,
    input txValid,
    output txReady
  );

  wire capture;
  wire sel;
  wire shift;
  wire tck;
  wire tdi;
  wire tms;
  wire tdo; 
  wire update;
  
  wire capture2;
  wire sel2;
  wire shift2;
  wire tck2;
  wire tdi2;
  wire tms2;
  wire tdo2; 
  wire update2;

  // Instantiate BSCAN primative
  BSCANE2 #(
    .JTAG_CHAIN(2) // Value for USER command.
  )
  bscan2_rx (
    .CAPTURE(capture), // 1-bit output: CAPTURE output from TAP controller.
    .DRCK(), // 1-bit output: Gated TCK output. When SEL is asserted, DRCK toggles when CAPTURE or SHIFT are asserted.
    .RESET(), // 1-bit output: Reset output for TAP controller.
    .RUNTEST(), // 1-bit output: Output asserted when TAP controller is in Run Test/Idle state.
    .SEL(sel), // 1-bit output: USER instruction active output.
    .SHIFT(shift), // 1-bit output: SHIFT output from TAP controller.
    .TCK(tck), // 1-bit output: Test Clock output. Fabric connection to TAP Clock pin.
    .TDI(tdi), // 1-bit output: Test Data Input (TDI) output from TAP controller.
    .TMS(tms), // 1-bit output: Test Mode Select output. Fabric connection to TAP.
    .UPDATE(update), // 1-bit output: UPDATE output from TAP controller
    .TDO(tdo) // 1-bit input: Test Data Output (TDO) input for USER function.
  );
  
  BSCANE2 #(
    .JTAG_CHAIN(1) // Value for USER command.
  )
  bscan2_tx (
    .CAPTURE(capture2), // 1-bit output: CAPTURE output from TAP controller.
    .DRCK(), // 1-bit output: Gated TCK output. When SEL is asserted, DRCK toggles when CAPTURE or SHIFT are asserted.
    .RESET(), // 1-bit output: Reset output for TAP controller.
    .RUNTEST(), // 1-bit output: Output asserted when TAP controller is in Run Test/Idle state.
    .SEL(sel2), // 1-bit output: USER instruction active output.
    .SHIFT(shift2), // 1-bit output: SHIFT output from TAP controller.
    .TCK(tck2), // 1-bit output: Test Clock output. Fabric connection to TAP Clock pin.
    .TDI(tdi2), // 1-bit output: Test Data Input (TDI) output from TAP controller.
    .TMS(tms2), // 1-bit output: Test Mode Select output. Fabric connection to TAP.
    .UPDATE(update2), // 1-bit output: UPDATE output from TAP controller
    .TDO(tdo2) // 1-bit input: Test Data Output (TDO) input for USER function.
  );

  wire [7:0] newJtagByte;
  wire newJtagByteValid; // True for 1 cycle per byte
  always @(posedge clk)
  begin
    if (rstn == 0)
    begin
      rxValid <= 0;
      rxByte <= 0;
    end else begin
      if (newJtagByteValid)
      begin
        rxByte <= newJtagByte; 
	    rxValid <= 1;
      end else begin
        rxValid <= 0; 
      end
    end
  end

  // 1. jtagAbsorbedByte - present for 1 cycle after jtag absorbs a byte
  // 2. newJtagByteValid - present for 1 cycle after jtag has a new byte
  // 3. newJtagByte - set to that byte 
  
  // CDC for transfering byte from jtag domain to AXI
  wire jtagSrcRx;
  reg [7:0] jtagRxByte = 0;
  reg jtagRxValid = 0;
  xpm_cdc_handshake #(
    .DEST_EXT_HSK(0),
    .DEST_SYNC_FF(4),
    .SRC_SYNC_FF(4),
    .SIM_ASSERT_CHK(1),
    .WIDTH(8)
  ) rxByteCDC (
    .dest_out(newJtagByte[7:0]),
    .dest_req(newJtagByteValid),
    .src_rcv(jtagSrcRx),
    .dest_ack(0),
    .dest_clk(clk),
    .src_clk(tck),
    .src_in(jtagRxByte),
    .src_send(jtagRxValid)
  );

  
  reg [7:0] jtagByte = 0;
  assign tdo = jtagByte[0];
  always @(posedge tck)
  begin
    if (sel & capture)
    begin 
      // Read - always AA
      jtagByte <= 8'hAA;
    end

    if (sel & shift)
    begin
      jtagByte <= {tdi,jtagByte[7:1]};
    end 
    if (sel & update)
    begin
     // Write byte outbound (Technically just starts the CDC)
     jtagRxByte <= jtagByte[7:0];
     jtagRxValid <= 1'b1;
    end else begin
      if (jtagSrcRx) jtagRxValid <= 0; // CDC Complete
    end
  end
  
  wire [7:0] txByteOut;
  wire txByteEmpty;
  wire txBufFull;


  // We must wait at least 8 clocks between bytes or crc will not calculate correctly!
  reg [3:0] gapCnt=0;
  always @(posedge clk)
  begin
    gapCnt = gapCnt+1;
  end
  // We will actually accept one-cycle after txReady asserts
  assign txReady = (~txBufFull) & (gapCnt[3:0] == 4'b0000) & (~txValid);

  FIFO18E2 #(
    .CASCADE_ORDER("NONE"),
    .CLOCK_DOMAINS("INDEPENDENT"),
    .FIRST_WORD_FALL_THROUGH("TRUE"),
    .INIT(36'h000000000),
    .READ_WIDTH(9),
    .WRITE_WIDTH(9),
    .REGISTER_MODE("UNREGISTERED"),
    .RSTREG_PRIORITY("RSTREG"),
    .SLEEP_ASYNC("FALSE"),
    .SRVAL(36'h000000000)
  ) write_fifo_inst (
    .DOUT(txByteOut),
    .EMPTY(txByteEmpty),
    .FULL(txBufFull),
    .RDCLK(tck2),
    .RDEN(sel2 & capture2),
    .REGCE(1'b1),
    .RSTREG(1'b0),
    .SLEEP(1'b0),
    .RST(1'b0),
    .WRCLK(clk),
    .WREN(txValid/* & txReady*/),
    .DIN(txByte[7:0])
  );
  
  reg [8:0] jtagByte2 = 0;
  assign tdo2 = jtagByte2[0];
  always @(posedge tck2)
  begin
    if (sel2 & capture2)
    begin 
      // Read  
      jtagByte2 <= {txByteEmpty,txByteOut[7:0]};
    end

    if (sel2 & shift2)
    begin
      jtagByte2 <= {tdi2,jtagByte2[8:1]};
    end 
  end
endmodule
