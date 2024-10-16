# i2c_and_spi_shared_regmap
A shared regmap with 2 bus interfaces (I2C and SPI 3wire). Three different clock domains all handled cleanly with an extremely simple bus arbitration. No fifo used, but read_data is buffered in two clock domains. 
