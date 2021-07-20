module sqrl_uart_xmit # (
	parameter comm_clk_frequency = 100000000,
	parameter baud_rate = 115200
) (
	input clk,

	// UART interface
	output uart_tx,

	// Data to send
	input tx_new_byte,
	input [7:0] tx_byte,

	// Status
	output tx_ready
);

	localparam [15:0] baud_delay = (comm_clk_frequency / baud_rate) - 16'd1;

	reg [15:0] delay_cnt = 16'd0;
	reg [9:0] state = 10'd1023, outgoing = 10'd1023;

	assign uart_tx = outgoing[0];
	assign tx_ready = state[0] & ~tx_new_byte;


	always @ (posedge clk)
	begin
		delay_cnt <= delay_cnt + 16'd1;

		if (delay_cnt >= baud_delay)
		begin
			delay_cnt <= 16'd0;
			state <= {1'b1, state[9:1]};
			outgoing <= {1'b1, outgoing[9:1]};
		end

		if (tx_new_byte && state[0])
		begin
			delay_cnt <= 16'd0;
			state <= 10'd0;
			outgoing <= {1'b1, tx_byte, 1'b0};
		end
	end

endmodule
