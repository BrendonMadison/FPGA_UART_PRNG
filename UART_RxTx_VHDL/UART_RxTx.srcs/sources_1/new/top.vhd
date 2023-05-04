----------------------------------------------------------------------------------
-- Written entirely by Brendon Madison of the Univ. of Kansas , 4th May 2023
-- This is the top file (controller) for all of the PRNG Computer modules (including UART)
-- 
-- This file should contain a finite state machine that controls the flow of
-- the PRNG that you are generating as well as the UART it uses to get from
-- the FPGA to the PC.
--
-- It also contains multiple baudrates (gBAUDRATE) and Tx packet lengths (gDEPTH)
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
generic(
	gDEPTH            : integer := 8;                        -- established number of bytes to read/write
	--gBAUDRATE         : integer := 868                       -- clock freq / baudrate (115200)
	gBAUDRATE         : integer := 108                       -- clock freq / baudrate (921600)
	);					             
    Port ( 
        clk           : in STD_LOGIC;
        --RXSW          : in STD_LOGIC;
        --RXrdy         : in STD_LOGIC;
        --TXrst         : in STD_LOGIC;
        Prst          : in STD_LOGIC;
        --RXrst         : in STD_LOGIC;
        --TXrdy      : in STD_LOGIC;
        RX_data_in    : in STD_LOGIC;
        --TX_data_in    : in STD_LOGIC_VECTOR(7 downto 0);
        -- Data_string   : in STD_LOGIC_VECTOR(63 downto 0);
        TX_data_out   : out STD_LOGIC;
        RX_data_out   : out STD_LOGIC_VECTOR(7 downto 0);
        TX_busy       : out STD_LOGIC;
        TX_finish     : out STD_LOGIC;
        P_finish      : out STD_LOGIC;
        RandomType    : out STD_LOGIC;
        G_finish      : out STD_LOGIC;
        G_starting    : out STD_LOGIC;
        G_ValLED      : out STD_LOGIC;
        RX_finish     : out STD_LOGIC
    );
end top;

architecture Behavioral of top is

component UART_top is
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
        TXrdy      : in STD_LOGIC;
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
end component;

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


component Gauss is
    port ( 
        clk           : in STD_LOGIC;
        iStart        : in STD_LOGIC;
        iData_in      : in STD_LOGIC_VECTOR (63 downto 0);
        iRst          : in STD_LOGIC;
        oData_out     : out STD_LOGIC_VECTOR (63 downto 0);
        oFinish       : out STD_LOGIC;
        oValid        : out STD_LOGIC
        );
end component;

type top_fsm_type is (idle_state,rx_state,tx_state);		-- finite state machine state for top

signal top_state : top_fsm_type := idle_state;

signal data_string : STD_LOGIC_VECTOR(63 downto 0);
signal data_hold   : STD_LOGIC_VECTOR(63 downto 0);
constant zeros     : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');

--acts as a signal version of TX_finish
signal tx_fin      : STD_LOGIC;
signal p_valid     : STD_LOGIC;

--counts the number of transmissions
--when the full data_string has been transmitted we get a new one
signal txcnt       : INTEGER range 0 to gDEPTH-1 := 0;

--gives the PRNG the signal to read in a new datastring
signal p_read      : STD_LOGIC := '0';

signal rx_fin      : STD_LOGIC;

signal rxrdy       : STD_LOGIC := '0';
signal txrdy       : STD_LOGIC := '0';
signal rxrst       : STD_LOGIC := '0';
signal txrst       : STD_LOGIC := '0';

signal gstart      : STD_LOGIC := '0';
signal gdatain     : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
signal gdataout    : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
signal gvalid      : STD_LOGIC := '0';
signal grst        : STD_LOGIC := '1';
signal gfin        : STD_LOGIC := '0';

signal rantype     : STD_LOGIC := '0';

begin

    comp_uart : UART_top port map(
        clk         => clk,
        RXrdy       => rxrdy,
        TXrst       => txrst,
        RXrst       => rxrst,
        TXrdy       => txrdy,
        RX_data_in  => RX_data_in,
        -- TX_data_in  => TX_data_in,
        Data_string => data_string,
        TX_data_out => TX_data_out,
        RX_data_out => RX_data_out,
        TX_busy     => TX_busy,
        TX_finish   => tx_fin,
        G_State     => rantype,
        RX_finish   => rx_fin
    );

    comp_prng : PRNG port map(
        clk         => clk,
        rst         => Prst,
        out_ready   => p_read,
        out_valid   => p_valid,
        out_data    => data_hold
    );
    
    comp_gauss : Gauss port map(
        clk         => clk,
        iStart      => gstart,
        iData_in    => gdatain,
        iRst        => grst,
        oData_out   => gdataout,
        oFinish     => gfin,
        oValid      => gvalid
    );

    TX_finish <= tx_fin;
    RX_finish <= rx_fin;
    P_finish  <= p_valid;
    RandomType <= rantype;
    G_finish <= gfin;
    G_starting <= gstart;
    G_ValLED <= gvalid;
 
    process(clk,p_valid)
    begin
        if p_valid <= '1' then
            p_read <= '0';
        end if;
        if(rising_edge(clk)) then
     
            case top_state is
        

        
                when idle_state => 
                    -- the ready signal must switch to load the new random string
                    txrst <= '1';
                    rxrst <= '1';
                    case rantype is
                    
                    when '0' =>
--                      This is the uniform random state
                        p_read <= '1';
                        if p_valid = '1' then
                            p_read <= '0';
                            data_string <= data_hold;
                            top_state <= rx_state;
                        end if;
                    when '1' =>
--                      This is the gaussian random state
                        if gvalid = '1' then
                            data_string <= STD_LOGIC_VECTOR(gdataout);
                            top_state <= rx_state;
                            grst <= '1';
                        end if;
--                    end if;
                    end case;
--                    if (p_valid = '1') then
--                        p_read <= '0';
--                        top_state <= rx_state;
--                    end if;
                
                when rx_state =>           
                --  Go to recieve a byte from the PC
                    rxrst <= '0';
                    txrst <= '0';
                    grst <= '0';
                    txrdy <= '1';                    
                --  Once RX is finished then go Tx
                    if (rx_fin = '1') then
                        rxrdy <= '0';
                        rxrst <= '1';
                        top_state <= tx_state;
                    end if;
                
                when tx_state =>
                --  Send your PRNG to the PC
                    txrst <= '0';
                    txrdy <= '1';
                    if (tx_fin = '1') then
                        top_state <= idle_state;
                        txrdy <= '0';
                    end if;
                                    
                when others =>
                    --this should never happen
                    --unless, idk, a cosmic ray hit your FPGA or something
                    top_state <= idle_state;
            end case;
        end if;
    end process;

end Behavioral;
