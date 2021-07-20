module sqrl_uart_recv # (
	parameter comm_clk_frequency = 100000000,
	parameter baud_rate = 115200
) (
	input clk,

	// UART interface
	input uart_rx,

	// Data received
	output reg rx_new_byte = 1'b0,
	output reg [7:0] rx_byte = 8'd0
);

	localparam [15:0] baud_delay = (comm_clk_frequency / baud_rate) - 16'd1;

	//-----------------------------------------------------------------------------
	// UART Filtering
	//-----------------------------------------------------------------------------
	wire rx;

	sqrl_uart_filter uart_fitler_blk (
		.clk (clk),
		.uart_rx (uart_rx),
		.tx_rx (rx)
	);


	//-----------------------------------------------------------------------------
	// UART Decoding
	//-----------------------------------------------------------------------------
	reg old_rx = 1'b1, idle = 1'b1;
	reg [15:0] delay_cnt = 16'd0;
	reg [8:0] incoming = 9'd0;

	always @ (posedge clk)
	begin
		old_rx <= rx;
		rx_new_byte <= 1'b0;

		delay_cnt <= delay_cnt + 16'd1;

		if (delay_cnt == baud_delay)
			delay_cnt <= 0;

		if (idle && old_rx && !rx)    // Start bit (falling edge)
		begin
			idle <= 1'b0;
			incoming <= 9'd511;
			delay_cnt <= 16'd0;   // Synchronize timer to falling edge
		end
		else if (!idle && (delay_cnt == (baud_delay >> 1)))
		begin
			incoming <= {rx, incoming[8:1]};    // LSB first

			if (incoming == 9'd511 && rx)       // False start bit
				idle <= 1'b1;
		
			if (!incoming[0])    // Expecting stop bit
			begin
				idle <= 1'b1;
				
				if (rx)
				begin
					rx_new_byte <= 1'b1;
					rx_byte <= incoming[8:1];
				end
			end
		end
	end

endmodule
