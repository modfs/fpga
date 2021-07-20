/*
* Provides metastability protection, and some minimal noise filtering.
* Noise is filtered with a 3-way majority vote. This removes any random single
* 'clk' cycle errors.
*/
module sqrl_uart_filter (
	input clk,
	input uart_rx,
	output reg tx_rx = 1'b0
);

	//-----------------------------------------------------------------------------
	// Metastability Protection
	//-----------------------------------------------------------------------------
	reg rx, meta;

	always @ (posedge clk)
		{rx, meta} <= {meta, uart_rx};


	//-----------------------------------------------------------------------------
	// Noise Filtering
	//-----------------------------------------------------------------------------
	wire sample0 = rx;
	reg sample1, sample2;

	always @ (posedge clk)
	begin
		{sample2, sample1} <= {sample1, sample0};

		if ((sample2 & sample1) | (sample1 & sample0) | (sample2 & sample0))
			tx_rx <= 1'b1;
		else
			tx_rx <= 1'b0;
	end

endmodule
