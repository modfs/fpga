`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/01/2020 02:59:09 AM
// Design Name: 
// Module Name: sqrl_interrupt_arb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sqrl_interrupt_arb(
    input clk,
    input interruptA,
    input interruptB,
    input [63:0] interruptDataA,
    input [63:0] interruptDataB,
    output [63:0] interruptDataO,
    output [3:0] interruptsO,

    input canaryA,
    input canaryB,
    input canaryC,
    input interruptAckAO,
    input interruptAckBO,
    input interruptAckCO,
    output interruptAckA,
    output interruptAckB
    );

    reg [1:0] canary = 0;
    always @(posedge clk)
    begin
      if (canaryA) 
	canary <= 0;
      else if (canaryB)
	canary <= 1;
      else if (canaryC)
	canary <= 2;
    end 

    wire selectBit = (interruptA?0:1);
    assign interruptsO[3:0] = (selectBit?{2'b00, interruptB, interruptB}:{3'b000,interruptA});
    assign interruptDataO = (selectBit?interruptDataB:interruptDataA);

    wire interruptAckO = ((canary==2)?interruptAckCO:((canary==1)?interruptAckBO:interruptAckAO));

    assign interruptAckA = (selectBit?1'b0:interruptAckO);
    assign interruptAckB = (selectBit?interruptAckO:1'b0);
endmodule
