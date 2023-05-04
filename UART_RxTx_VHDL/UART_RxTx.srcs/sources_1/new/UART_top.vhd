----------------------------------------------------------------------------------
-- Written entirely by Brendon Madison of the Univ. of Kansas , 4th May 2023
-- This is the top file (controller) for the UART modules
-- 
-- If you want to use the UART_Tx and UART_Rx modules you should use and change this
--
-- This file should contain whatever logic you want the FPGA to do with 
-- the UART modules. Things like loading in settings etc.
--
-- It also contains multiple baudrates (gBAUDRATE) and Tx packet lengths (gDEPTH)
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_top is
generic(
	gDEPTH            : integer := 8;                        -- established number of bytes to read/write
	--gBAUDRATE         : integer := 868                       -- clock freq / baudrate (115200)
	gBAUDRATE         : integer := 108                       -- clock freq / baudrate (921600)
	);					             
    Port ( 
        clk           : in STD_LOGIC;
        RXrdy         : in STD_LOGIC;
        TXrst         : in STD_LOGIC;
        RXrst         : in STD_LOGIC;
        TXrdy         : in STD_LOGIC;
        RX_data_in    : in STD_LOGIC;
        -- TX_data_in    : in STD_LOGIC_VECTOR(7 downto 0);
        Data_string   : in STD_LOGIC_VECTOR(63 downto 0);
        TX_data_out   : out STD_LOGIC;
        RX_data_out   : out STD_LOGIC_VECTOR(7 downto 0);
        TX_busy       : out STD_LOGIC;
        TX_finish     : out STD_LOGIC;
        G_State       : out STD_LOGIC := '0';
        RX_finish     : out STD_LOGIC
    );
end UART_top;

architecture Behavioral of UART_top is

component UART_TX is
generic(
	clk_baudrate : integer := 108 );					    -- (10000000 / 115200 )
port(	clk           : in std_logic;						-- clock
		rst           : in std_logic;						-- reset
		TX_start      : in std_logic;						-- when active start transmission
		TX_data_in    : in std_logic_vector(7 downto 0);	-- 8 bit data to send
		TX_data_out   : out std_logic;					    -- data sent through TX line
		TX_busy       : out std_logic;						-- active when transmitter is sending data
		TX_finish     : out std_logic );					-- active when transmission is done
end component;

component UART_RX is
generic(
	clk_baudrate : integer := 108 );                        -- (100000000) / (115200)					
port(	clk           : in std_logic;						-- clock
		rst           : in std_logic;						-- reset
		rdy           : in std_logic;                       -- ready input
		RX_data_in    : in std_logic;					    -- RX line input
		RX_data_out   : out std_logic_vector(7 downto 0);	-- 8 bit data received
		RX_finish     : out std_logic );					-- active when data is received
end component;

signal txtrigger : STD_LOGIC;
signal pword     : STD_LOGIC;
signal tdone     : STD_LOGIC;
signal rxdata    : STD_LOGIC_VECTOR(7 downto 0);
signal txbitcnt  : INTEGER range 0 to gDEPTH-1 := 0;
signal readflag  : STD_LOGIC := '0';

signal TXd_buff  : STD_LOGIC_VECTOR(7 downto 0);

--signal rxrst     : STD_LOGIC;

--Test data string that represents ABCDEFGH with start byte of !
constant StartStopByte  : STD_LOGIC_VECTOR(7 downto 0)  := "00100001";
signal DataStr    : STD_LOGIC_VECTOR(gDEPTH*8 - 1 downto 0);

begin

    comp_rx : UART_RX port map(
        clk         => clk, 
        rst         => rxrst,
        rdy         => RXrdy, 
        RX_data_in  => RX_data_in, 
        RX_data_out => rxdata,
        RX_finish   => RX_finish
    );

    comp_tx : UART_TX port map(
        clk         => clk, 
        rst         => TXrst,
        TX_start    => txtrigger,
        TX_data_in  => TXd_buff,
        TX_data_out => TX_data_out,
        TX_busy     => TX_busy,
        TX_finish   => tdone
    );

    TX_finish <= tdone;
    RX_data_out <= rxdata;

    -- process to catch various input bytes
    -- such as the "read" byte that is "B" = 01000010
    process(clk)
    begin
        -- load the data into the buffer on the raising edge
        if (clk'event and clk = '1') then
            TXd_buff <= DataStr(7 downto 0);
            if (readflag = '1') then
                if (TXrdy = '1') then
                    txtrigger <= '1';
                    TXd_buff <= DataStr(((txbitcnt+2)*8 - 1) downto (txbitcnt+1)*8);
                end if;
            end if;
        end if;
        -- send out the data on the falling edge
        if (clk'event and clk = '0') then
            if (tdone = '1') then
                txtrigger <= '0';
                txbitcnt <= txbitcnt + 1;
                --rxrst <= '1';
            end if;
            -- Check if we are ready to send (TXrdy)
            -- If we are and the readflag is flipped then flip the TX switch (txtrigger)
            if (readflag = '1') then
                if (TXrdy = '1') then
                    txtrigger <= '1';
                    --TXd_buff <= TestDataStr(((txbitcnt+1)*8 - 1) downto txbitcnt*8);
                else
                    txtrigger <= '0';
                end if;
            end if;
            -- The read flag signals to begin reading though resets so
            -- there isn't a continuous reading
            -- If we receive a "B" then we need to send data
            case rxdata is
            
                when "01000010" =>
                    readflag <= '1';
                    txbitcnt <= 0;
                    --rxrst <= '1';
                    DataStr <= Data_string;

                -- If we receive an "G" then we need to set the G_state to high so top knows to do gaussian random
                when "01000111" =>
                    G_state <= '1';
                    readflag <= '1';
                    txbitcnt <= 0;
                    --rxrst <= '1';
                    DataStr <= Data_string;
    
                -- If we receive an "U" then we need to set the G_state to low so top knows to do uniform random                
                when "01010101" =>
                    G_state <= '0';
                    readflag <= '1';
                    txbitcnt <= 0;
                    --rxrst <= '1';
                    DataStr <= Data_string ;
                    
                when others =>
            end case;
            
            if (txbitcnt = gDEPTH-1) then
                readflag <= '0';
                --rxrst <= '0';
            end if;
        end if;
    end process;
                
end Behavioral;
