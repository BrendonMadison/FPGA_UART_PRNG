# FPGA_UART_PRNG
Uses serial UART to transmit Pseudo Random Numbers , of Uniform or Gaussian type, to a computer in such a way that it can be invoked, live, in C++ code

# PRNG Methods:

Uniform random is created using the FPGA Xoroshiro128+ method as outlined here : https://github.com/jorisvr/vhdl_prng

Gaussian random is created using the Irwin-Hall method of summing uniform random numbers. As the number of sums increases the distribution approaches a gaussian with a mean of 0.5 and width of 0. The number of sums used is 16 since it gives decent quality and is easy to divide by 16 in binary/VHDL. The gaussian random numbers here have a mean of 0.5 and stdev. of sqrt(1.0/(16.0*12.0)) ~= 0.072 .

# UART , PC Serial Embedding :

Using two UART modules (UART_Tx and UART_Rx) the FPGA is essentially embedded into the PC as a serial port object that can be used to generate Gaussian or Uniform random numbers at the request of the PC (or its user) in C++. Two C++ programs are provided with settings for Gaussian and Uniform respectively.

# PRNG Quality

The PRNG has a 124 bit period and 64 bit width. For the Gaussian the period is technically 124 bit because of dividing by 16 in the Irwin-Hall method. From this we found that there is typically 40 digits (technically more but the last digit is 1/4th precise) of floating point precision after converting to long double type in C++.

Both distributions were fit using Binned Least Log Likelihood for 1M samples using ROOT. Both distributions have reduced Chi2 near 1.0 indicating acceptable performance and correct data exchange between PC and FPGA.

# Speed

The main limit to execution speed is the USB port latency. For Windows this can only be reduced to 1 ms. So 1M samples takes 1000 seconds. The FPGA used for this demo was the Nexys A7 where a max execution time "worse case scenario" of ~4.5 ns was found using timing analysis. This was smaller than the Nexys A7's clock period (10 ns) so the program is able to compute without issues even under the worst case scenario. A baud rate of 960kHz was used though 152kHz and 9.6kHz were tested too. As such the maximum data rate, assuming the latency issues were resolved, would be limitted by the baud rate. For 960kHz and including that the PC must query the FPGA to send data, the maximum data rate would be ~930 kb/s .
