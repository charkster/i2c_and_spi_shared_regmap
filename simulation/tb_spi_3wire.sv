module tb_i2c_and_spi_3wire ();

   parameter EXT_CLK_PERIOD_NS = 4900;
   parameter SCLK_PERIOD_NS    = 9800;
   
   reg  clk;
   reg  button_0;
   reg  sclk;
   reg  ss_n;
   reg  sdata_out;
   reg  sdata_oe;
   wire sdata;
   
   wire sda;
   wire scl;
   
   pullup(sda);
   pullup(scl);
   
   // I2C Master instance
   i2c_master
      #( .value   ( "FAST" ),  // 400kHz
         .scl_min ( "HIGH" ) ) // this is the most aggressive
   u_mstr_i2c
     ( .sda       ( sda ), // inout
       .scl       ( scl )  // output
     );
     
   logic  [7:0] i2c_read_data;
   logic [15:0] i2c_read_word;
   
   initial begin
      clk = 1'b0;
      forever
        #(EXT_CLK_PERIOD_NS/2) clk = ~clk;
   end
   
   bidir bidir_sdata
   (
    .pad    (sdata),     // inout
    .to_pad (sdata_out), // input
    .oe     (sdata_oe)   // input
    );

   task send_byte (input [7:0] byte_val);
      begin
         $display("Called send_byte task: given byte_val is %h",byte_val);
         sclk     = 1'b0;
         for (int i=7; i >= 0; i=i-1) begin
            $display("Inside send_byte for loop, index is %d",i);
            sdata_out = byte_val[i];
            #(SCLK_PERIOD_NS/2);
            sclk  = 1'b1;
            #(SCLK_PERIOD_NS/2);
            sclk  = 1'b0;
         end
      end
   endtask

   initial begin
      button_0  = 1'b1;
      sclk      = 1'b0;
      ss_n      = 1'b1;
      sdata_oe  = 1'b1;
      sdata_out = 1'b0;
      #SCLK_PERIOD_NS;
      button_0  = 1'b0;    
      #20us;
      $display("Write 4 bytes to regmap address 0x00");
      #(SCLK_PERIOD_NS*8);
      ss_n      = 1'b0;
      #(SCLK_PERIOD_NS/2);
      sdata_oe  = 1'b1;
      send_byte(8'h00);
      send_byte(8'hE5);
      send_byte(8'h24);
      send_byte(8'h1F);
      send_byte(8'h71);
      sdata_oe  = 1'b0;
      #(SCLK_PERIOD_NS/2);
      ss_n      = 1'b1;
      $display("Read 3 bytes from regmap address 0x01");
      #(SCLK_PERIOD_NS*8);
      ss_n      = 1'b0;
      #(SCLK_PERIOD_NS/2);
      sdata_oe  = 1'b1;
      send_byte(8'h81);
      sdata_oe  = 1'b0;
      send_byte(8'h00);
      send_byte(8'h00);
      send_byte(8'h00);
      send_byte(8'h00);
      #(SCLK_PERIOD_NS/2);
      ss_n      = 1'b1;
      $display("Write 1 byte to regmap address 0x02");
      #155us;
      #400ns;
      #(SCLK_PERIOD_NS*8);
      ss_n      = 1'b0;
      #(SCLK_PERIOD_NS/2);
      sdata_oe  = 1'b1;
      send_byte(8'h02);
      send_byte(8'h92);
      sdata_oe  = 1'b0;
      #(SCLK_PERIOD_NS/2);
      ss_n      = 1'b1;
      $display("Read 4 byte from regmap address 0x00");
      #(SCLK_PERIOD_NS*8);
      ss_n      = 1'b0;
      #(SCLK_PERIOD_NS/2);
      sdata_oe  = 1'b1;
      send_byte(8'h80);
      sdata_oe  = 1'b0;
      send_byte(8'h00);
      send_byte(8'h00);
      send_byte(8'h00);
      send_byte(8'h00);
      send_byte(8'h00);
      #(SCLK_PERIOD_NS/2);
      ss_n      = 1'b1;
      #30us;
      $finish;
   end
   
   // simultaneous SPI and I2C bus cycles
   initial begin
      #40us;
      u_mstr_i2c.i2c_write(7'h24, 8'h02, 8'h3A);
      #501us;
      u_mstr_i2c.i2c_read (7'h24, 8'h02, i2c_read_data);
      u_mstr_i2c.i2c_write(7'h24, 8'h00, 8'hC2);
      #30us;
      //$finish;
   end

   i2c_spi_no_fifo_top u_i2c_spi_no_fifo_top
     ( .clk,
       .button_0,
       .scl,
       .sda,
       .sclk,
       .ss_n,
       .sdata
       );

endmodule
