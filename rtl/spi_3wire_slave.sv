module spi_3wire_slave
  ( input  logic       rst_n, // reset button
    input  logic       sclk,  // SPI CLK
    input  logic       ss_n,  // SPI CS_N
    inout  logic       sdata, // MOSI/MISO combined
    input  logic [7:0] rdata,
    output logic [7:0] wdata,
    output logic [6:0] addr,
    output logic       rd_en,
    output logic       wr_en
    );

  logic       rst_n_sync;
  logic       rst_n_spi;
  logic [4:0] bit_count;
  logic       rnw;
  logic       sdata_out;
  logic       sdata_oe;
  logic [7:0] hold_read_data;
  logic [6:0] shift_wdata;
  logic       multicycle;
  
  logic [7:0] registers[127:0]; // 128 bytes

//  synchronizer u_synchronizer_rst_n_sync
//   ( .clk      (sclk),
//     .rst_n    (rst_n),
//     .data_in  (1'b1),
//     .data_out (rst_n_sync)
//     );

  assign rst_n_sync = rst_n; // don't synchronize for now

  bidir bidir_sdata
  (
   .pad    (sdata),     // inout
   .to_pad (sdata_out), // input
   .oe     (sdata_oe)   // input
   );

  assign rst_n_spi = rst_n && !ss_n; // clear the SPI interface flipflops when the chip_select is inactive
   
  always_ff @(posedge sclk, negedge rst_n_spi)
    if (~rst_n_spi)                         bit_count <= 'd0;
    else if ((!rnw) && (bit_count == 'd15)) bit_count <= 'd8; // allow for address auto increment on write
    else if (  rnw  && (bit_count == 'd18)) bit_count <= 'd11; // allow for address auto increment on read
    else                                    bit_count <= bit_count + 1;
  
  // this is needed for write cycle address auto-increment
  always_ff @(posedge sclk, negedge rst_n_spi)
    if (~rst_n_spi)             multicycle <= 1'b0;
    else if (bit_count == 'd15) multicycle <= 1'b1;
    
  always_ff @(posedge sclk, negedge rst_n_spi)
     if (~rst_n_spi)              rnw <= 1'd0;
     else if ((bit_count == 'd0)) rnw <= sdata;

   always_ff @(posedge sclk, negedge rst_n)
     if (~rst_n)                                        addr <= 7'd0;
     else if ((bit_count >= 'd1) && (bit_count <= 'd7)) addr <= {addr[5:0],sdata};
     else if ((bit_count == 'd15) &&   rnw)             addr <= addr + 1'd1; // auto increment read
     else if ((bit_count == 'd15) && multicycle)        addr <= addr + 1'd1; // auto increment write
   
   always_ff @(posedge sclk, negedge rst_n_spi)
     if (~rst_n_spi)                      shift_wdata <= 7'd0;
     else if (!rnw && (bit_count >= 'd8)) shift_wdata <= {shift_wdata[5:0],sdata};
   
   always_ff @(posedge sclk, negedge rst_n)
     if (~rst_n)                           wdata <= 8'd0;
     else if (!rnw && (bit_count == 'd15)) wdata <= {shift_wdata[6:0],sdata};
   
   always_ff @(posedge sclk, negedge rst_n)
     if (~rst_n)                             wr_en <= 1'b0;
     else if ((bit_count == 'd15) && (!rnw)) wr_en <= 1'b1;
     else if ((bit_count == 'd11) && wr_en)  wr_en <= 1'b0;
   
   always_ff @(posedge sclk, negedge rst_n_spi)
     if (~rst_n_spi)                                              rd_en <= 1'b0;
     else if (((bit_count == 'd9) || (bit_count == 'd17)) && rnw) rd_en <= 1'b1;
     else                                                         rd_en <= 1'b0;
   
   always_ff @(posedge sclk, negedge rst_n_spi)
     if (~rst_n_spi) hold_read_data <= 8'd0;
     else if (rd_en) hold_read_data <= rdata;
   
   assign sdata_oe = (bit_count >= 'd9) && rnw;
   
   always_ff @(posedge sclk, negedge rst_n_spi)
     if (~rst_n_spi)                sdata_out <= 1'd0;
     else if (rnw) case(bit_count)
                              'd11: sdata_out <= hold_read_data[7];
                              'd12: sdata_out <= hold_read_data[6];
                              'd13: sdata_out <= hold_read_data[5];
                              'd14: sdata_out <= hold_read_data[4];
                              'd15: sdata_out <= hold_read_data[3];
                              'd16: sdata_out <= hold_read_data[2];
                              'd17: sdata_out <= hold_read_data[1];
                              'd18: sdata_out <= hold_read_data[0];
                         endcase
     else                           sdata_out <= 1'b0;

endmodule
