# i2c_and_spi_shared_regmap
A shared regmap with 2 bus interfaces (I2C and SPI 3wire). Three different clock domains all handled cleanly with an extremely simple bus arbitration. No fifo is needed, but read_data is buffered in two clock domains.

The core clock needs to be at least half of the fastest bus clock frequency. For example if the I2C clock is 400kHz and the SPI clock is 1MHz, the slowest core clock frequency is 500kHz (it can be infinitely faster, but no slower). If the I2C clock is 400kHz and the SPI clock is 100kHz, the slowest core clock would be 200kHz. If SPI and I2C buses are simultaneously trying to access the shared regmap, the SPI bus has priority and the I2C bus will get access on the next core clock cycle (isn't this simple).

The SPI variant used here is a 3wire, but minimal changes would allow a 4wire to be used (see [spi_slave_lbus](https://github.com/charkster/cmod_a7_spi_sram/blob/master/spi_slave_lbus.sv) in my [cmod_a7_spi_sram](https://github.com/charkster/cmod_a7_spi_sram) repository.
