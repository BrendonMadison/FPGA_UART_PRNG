----------------------------------------------------------------------------------
-- Written entirely by Brendon Madison of the Univ. of Kansas , 4th May 2023
-- Uses the Irwin-Hall method to generate gaussian random number (GPRNG)
-- The seed and source random numbers come from the Xoroshiro128+ PRNG
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Gauss is
    Port ( clk           : in STD_LOGIC;
           iStart        : in STD_LOGIC;
           iData_in      : in STD_LOGIC_VECTOR (63 downto 0);
           iRst          : in STD_LOGIC;
           oData_out     : out STD_LOGIC_VECTOR (63 downto 0);
           oFinish       : out STD_LOGIC;
           oValid        : out STD_LOGIC
         );
end Gauss;

architecture Behavioral of Gauss is

component PRNG is
    generic (
        -- Default seed value.
        init_seed     : STD_LOGIC_VECTOR(127 downto 0) := (5 => '1' , 120 => '1', others => '0') 
        );

    port (
        clk           : in STD_LOGIC;
        rst           : in STD_LOGIC;
        out_ready     : in STD_LOGIC;
        out_valid     : out STD_LOGIC;
        out_data      : out STD_LOGIC_VECTOR(63 downto 0)
        );
end component;

--We need multiple uniform randoms in order to use this method.
--This follows from the Irwin-Hall distribution (distribution of sum of uniform randoms)
--In the central limit theorem for large numbers of Irwin-Hall distributed numbers it becomes Gaussian
--With a mean of n/2 and stdev of n/12
--We use twelve so mean of 6 and stdev of 1.0
--HOWEVER this is using unsigned 64 bit so it isn't 6 and 1.0 ...
signal irwin_hall      : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
--for 16 sums we will have a mean of 0.5 and stdev of sqrt(1.0/(12*16)) ~= 0.072
signal sum_cnt         : INTEGER range 0 to 16 := 0;
signal p_cnt           : INTEGER range 0 to 5 := 0;
signal add_flag        : STD_LOGIC := '0';

signal prst            : STD_LOGIC := '0';
signal p_read          : STD_LOGIC := '0';
signal p_valid         : STD_LOGIC := '0';
signal data_hold       : STD_LOGIC_VECTOR(63 downto 0);
signal new_data        : UNSIGNED(63 downto 0);

begin

    comp_prng : PRNG port map(
        clk         => clk,
        rst         => prst,
        out_ready   => p_read,
        out_valid   => p_valid,
        out_data    => data_hold
    );

process (clk,p_valid)
begin

    if (iRst = '1') then
        sum_cnt <= 0;
        irwin_hall <= (others => '0');
        oFinish <= '0';
        oValid <= '0';

    if p_valid = '1' then
        p_read <= '0';
    end if;

    elsif(clk'event and clk = '1') then

        p_read <= '1';
        prst <= '0';
        irwin_hall <= STD_LOGIC_VECTOR(new_data);
        --If p_valid is high then we can do the sum
        if p_valid = '1' then 
            p_read <= '0';
            if sum_cnt = 0 then
                sum_cnt <= sum_cnt + 1; 
                --We are dividing every sum by 16 since we are adding 16 values
                --this is a part of the Irwin-Hall scheme
                new_data <= "0000" & unsigned(data_hold(59 downto 0));
            elsif sum_cnt < 16 then
                sum_cnt <= sum_cnt + 1;
                new_data <= unsigned(irwin_hall) + unsigned("0000" & data_hold(59 downto 0));
            elsif sum_cnt = 16 then
                oValid <= '1';
                oData_out <= STD_LOGIC_VECTOR(new_data);
            end if;
        end if;
    end if;
    

end process;

end Behavioral;
