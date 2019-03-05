--import libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity baud_rate_converter is
 Port (
 CLK: in STD_LOGIC;
 RX: in STD_LOGIC;
 TX: out STD_LOGIC;
 LED1: out STD_LOGIC
 );
--both UARTS: 8N1
end baud_rate_converter;

architecture Behavioral of baud_rate_converter is

 type STATES is (
	state_idle,  -- waiting for transmission
	state_dly,  --delay
	state_r,   --reading only (1st bit)
	state_rw,  -- reading and writing //???
	state_w   --only writing (end of reception, transmission still in process)
	);
 signal state : STATES := state_idle;
 --BaudRate DIViders 
 constant BRdiv_out: unsigned := x"01B2"; -- 50MHz / 115200bps = 434
 constant BRdiv_in: unsigned := x"1458"; -- 50MHz / 9600bps = 5208
 
 
 --BitCounters
 signal Bcnt_in : unsigned(3 downto 0) :=b"0000";
 signal Bcnt_out : unsigned(3 downto 0) :=b"0000";
 
 --constant Bcntmax : natural := 12; --1xSTART + 8xDATA + 1xPARITY + 2xSTOP 
 -- 8N1
 constant Bcntmax : unsigned := x"A"; --1xSTART + 8xDATA + 0xPARITY + 1xSTOP = 10xBITS
 signal rx_buf : STD_LOGIC_VECTOR(9 downto 0);
 
 -- line states
 signal rx_now: STD_LOGIC :='1';
 signal rx_old : STD_LOGIC :='1'; --old
 signal tx_now : STD_LOGIC :='1';
 -- Tick Counter
 signal Tcnt_in : unsigned(15 downto 0) := x"0000";
 signal Tcnt_out : unsigned(15 downto 0) := b"0000000000000000";

 signal idle : STD_LOGIC :=  '1';
 constant read_delay : unsigned := x"0064"; -- 100

 begin
 process(CLK)
  begin
  if rising_edge(CLK) then --@50MHz
 case state is
---- IDLE
	when state_idle =>
		idle <= '1';
		-- detect start of transmission
		rx_old <= rx_now;
		rx_now <= RX;
		if ((rx_old= '1') and (rx_now = '0')) then 
			----reset counters
			Tcnt_in <= (others => '0');
			Tcnt_out <= (others => '0');
			Bcnt_in <= (others => '0'); 
			Bcnt_out <= (others => '0'); 
			rx_buf <= (others => '0'); --reset buffer
			idle <='0'; --not idle
			
			-- out is faster than in => read all first
			--if BRdiv_out < BRdiv_in then
				state <= state_dly;
			--end if;
			-- out is slower than in => read/write can be done simultanously			
			--if BRdiv_out >  BRdiv_in then
			--	state <= state_rw;
			--end if;
		end if;
-- A LITT'L DELAY
	when state_dly =>
		Tcnt_in <= Tcnt_in+1;
		if Tcnt_in = read_delay then
			Tcnt_in <= BRdiv_in -1; --read 1st bit (start) immidetly in next state
			state <= state_r;
		end if;
---- READ AND WRITE
--	when state_rw =>
--		Tcnt_in <= Tcnt_in+1;
--		Tcnt_out <= Tcnt_out+1;
--		--read first!
--		if Tcnt_in = BRdiv_in then
--			Tcnt_in <= (others => '0');
--			Bcnt_in <= Bcnt_in+1;
--			rx_buf(9 downto 1) <= rx_buf(8 downto 0);
--			--rx_buf(0) <= RX;
--			rx_buf(0) <= RX;
--		end if;
--		
--		if Tcnt_out = BRdiv_out then
--		end if;
---- READ ONLY
	when state_r =>
		Tcnt_in <= Tcnt_in+1; --increment counter
		if Tcnt_in = BRdiv_in then
			Tcnt_in <= x"0000";
			Bcnt_in <= Bcnt_in+1;
			rx_buf(9 downto 1) <= rx_buf(8 downto 0);
			rx_buf(0) <= RX;
		end if;
		if Bcnt_in = Bcntmax then
			state <= state_w;
		end if;
		
		
---- WRITE ONLY
	when state_w =>
		Tcnt_out <= Tcnt_out+1;
		if Tcnt_out = BRdiv_out then
			Tcnt_out <= (others => '0');
			Bcnt_out <= Bcnt_out+1;
			tx_now <= rx_buf(9);
			rx_buf(9 downto 1) <= rx_buf(8 downto 0);
		end if;
		if Bcnt_out = Bcntmax then
			state <= state_idle;
			idle <= '1';
		end if;
---- DEFAULTS
	when others =>
		state <= state_idle;
	end case;
  end if;
 end process;
 TX <= tx_now;
 LED1 <= idle;
end Behavioral;  
