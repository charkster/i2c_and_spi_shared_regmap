
module i2c_spi_no_fifo_top
( input  logic clk,      // board clock, this should be faster than SCL
  input  logic button_0, // button closest to PMOD connector
  input  logic scl,
  inout  wire  sda,
  input  logic sclk,  // SPI CLK
  input  logic ss_n,  // SPI CS_N
  inout  wire  sdata  // MOSI/MISO combined
  );

  parameter MAX_ADDRESS = 7'd127;
  
  logic       sda_out;
  logic       sda_in;
  logic       rst_n;
  logic       rst_n_sync;
  logic       rst_n_sclk;
  logic       wr_en_wdata;
  logic       wr_en_wdata_sync;
  logic       rd_en_trig;
  logic       rd_en_trig_sync;
  logic [7:0] i2c_addr;
  logic [7:0] i2c_rdata;
  logic [7:0] i2c_wdata;
  logic       wr_en_wdata_sync_hold;
  logic       wr_en_wdata_redge;
  logic       wr_en_wdata_redge_hold;
  logic       rd_en_trig_sync_hold;
  logic       rd_en_trig_redge;
  logic       rd_en_trig_redge_hold;
  
  logic       spi_wr_en;
  logic       spi_rd_en;
  logic       spi_wr_en_sync;
  logic       spi_rd_en_sync;
  logic       spi_wr_en_sync_hold;
  logic       spi_rd_en_sync_hold;
  logic       spi_wr_en_redge;
  logic       spi_rd_en_redge;
  logic       spi_cycle;
  logic       ss_n_sync;

  logic [6:0] addr;
  logic [7:0] wdata;
  logic [7:0] rdata;

  logic [6:0] spi_addr;
  logic       sdata_out;
  logic       sdata_oe;
  logic [7:0] spi_wdata;
  logic [7:0] spi_rdata;
  
  logic [7:0] registers[127:0]; // 128 bytes
  
  
  assign sda_in = sda; // this is for read-ablity
  
  assign rst_n = ~button_0; // button is high when pressed
  
// I2C SECTION  
  
  // button_0 is high when pressed
  synchronizer u_synchronous_rst_n
  ( .clk,                  // input
    .rst_n,                // input
    .data_in  (1'b1),      // input
    .data_out (rst_n_sync) // output
  );
    
  bidir u_sda
  ( .pad    ( sda ),     // inout
    .to_pad ( sda_out ), // input
    .oe     ( ~sda_out)  // input, open drain
  );

  i2c_slave 
  # ( .SLAVE_ID(7'h24) )
  u_i2c_slave
  ( .rst_n      (rst_n_sync), // input 
    .scl,                     // input 
    .sda_in,                  // input 
    .sda_out,                 // output  
    .i2c_active (),           // output 
    .rdata      (i2c_rdata),  // input [7:0]
    .addr       (i2c_addr),   // output [7:0]
    .wdata      (i2c_wdata),  // output [7:0]
    .wr_en_wdata,             // output
    .rd_en_trig               // output
  );
  
  synchronizer u_wr_en_sync
  ( .clk,                        // input
    .rst_n    (rst_n_sync),      // input
    .data_in  (wr_en_wdata),     // input
    .data_out (wr_en_wdata_sync) // output
  );
  
  always_ff @ (posedge clk, negedge rst_n_sync)
    if (!rst_n_sync) wr_en_wdata_sync_hold <= 1'b0;
    else             wr_en_wdata_sync_hold <= wr_en_wdata_sync;
    
  assign wr_en_wdata_redge = wr_en_wdata_sync && (!wr_en_wdata_sync_hold);
  
  always_ff @ (posedge clk, negedge rst_n_sync)
      if (!rst_n_sync) wr_en_wdata_redge_hold <= 1'b0;
      else             wr_en_wdata_redge_hold <= wr_en_wdata_redge;
  
  synchronizer u_rd_en_trig_sync
    ( .clk,                       // input
      .rst_n    (rst_n_sync),     // input
      .data_in  (rd_en_trig),     // input
      .data_out (rd_en_trig_sync) // output
    );
    
  always_ff @ (posedge clk, negedge rst_n_sync)
    if (!rst_n_sync) rd_en_trig_sync_hold <= 1'b0;
    else             rd_en_trig_sync_hold <= rd_en_trig_sync;
    
  assign rd_en_trig_redge = rd_en_trig_sync && (!rd_en_trig_sync_hold);
  
  always_ff @ (posedge clk, negedge rst_n_sync)
      if (!rst_n_sync) rd_en_trig_redge_hold <= 1'b0;
      else             rd_en_trig_redge_hold <= rd_en_trig_redge;
  
  // SPI given priority, either wr_en_wdata_redge or wr_en_wdata_redge_hold will be high when SPI is not using shared addr 
  integer j;
  always_ff @(posedge clk, negedge rst_n_sync)
    if (!rst_n_sync)                                            for (j=0; j<=MAX_ADDRESS; j=j+1) registers[j]    <= 8'h00;
    else if (spi_wr_en_redge || ((!spi_cycle) && (wr_en_wdata_redge || wr_en_wdata_redge_hold))) registers[addr] <= wdata;
  
  // SPI given priority, as SCLK is faster than SCL and SS_N will reset SPI block registers when it goes high
  assign spi_cycle = spi_rd_en_redge || spi_wr_en_redge;
  assign addr      = (spi_cycle)       ? spi_addr  : i2c_addr;
  assign wdata     = (spi_wr_en_redge) ? spi_wdata : i2c_wdata;
  assign rdata     = registers[addr];

  // hold I2C read data, get when SPI not using addr
  always_ff @(posedge clk, negedge rst_n_sync)
    if (!rst_n_sync)                                                      i2c_rdata <= 'd0;
    else if ((!spi_cycle) && (rd_en_trig_redge || rd_en_trig_redge_hold)) i2c_rdata <= rdata;
  
  always_ff @(posedge clk, negedge rst_n_sync)
    if (!rst_n_sync)          spi_rdata <= 'd0;
    else if (spi_rd_en_redge) spi_rdata <= rdata;

// SPI SECTION

  spi_3wire_slave u_spi_3wire_slave
  ( .rst_n (rst_n_sync), // input
    .sclk,               // input
    .ss_n,               // input
    .sdata,              // inout
    .rdata (spi_rdata),  // input  [7:0]
    .wdata (spi_wdata),  // output [7:0]
    .addr  (spi_addr),   // output [6:0]
    .rd_en (spi_rd_en),  // output
    .wr_en (spi_wr_en)   // output
    );
    
  synchronizer u_ss_n_sync
  ( .clk,                   // input
    .rst_n    (rst_n_sync), // input
    .data_in  (ss_n),       // input
    .data_out (ss_n_sync)   // output
  );
     
  synchronizer u_spi_rd_en_sync
  ( .clk,                      // input
    .rst_n    (rst_n_sync),    // input
    .data_in  (spi_rd_en),     // input
    .data_out (spi_rd_en_sync) // output
  );
  
  always_ff @(posedge clk, negedge rst_n_sync)
    if (!rst_n_sync) spi_rd_en_sync_hold <= 1'b0;
    else             spi_rd_en_sync_hold <= spi_rd_en_sync;
  
  assign spi_rd_en_redge = spi_rd_en_sync && (!spi_rd_en_sync_hold);
  
  synchronizer u_spi_wr_en_sync
  ( .clk,                      // input
    .rst_n    (rst_n_sync),    // input
    .data_in  (spi_wr_en),     // input
    .data_out (spi_wr_en_sync) // output
  );
  
  always_ff @(posedge clk, negedge rst_n_sync)
    if (!rst_n_sync) spi_wr_en_sync_hold <= 1'b0;
    else             spi_wr_en_sync_hold <= spi_wr_en_sync;
  
  assign spi_wr_en_redge = spi_wr_en_sync && (!spi_wr_en_sync_hold);

endmodule
