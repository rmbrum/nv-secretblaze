--
--    ADAC Research Group - LIRMM - University of Montpellier / CNRS 
--    contact: adac@lirmm.fr
--
--    This file is part of SecretBlaze.
--
--    SecretBlaze is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    SecretBlaze is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with SecretBlaze.  If not, see <http://www.gnu.org/licenses/>.
--

-----------------------------------------------------------------
-----------------------------------------------------------------
--                                                             
--! @file uart_controller.vhd
--! @brief Small UART Controller (8-N-1 mode only)
--! @author Lyonel Barthe
--! @version 1.1
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision history
--
-- Version 1.1 14/10/2010 by Lyonel Barthe
-- Changed the rx synchronizer to the double buffer method
-- Tx output registered
-- Busy flag registered
--
-- Version 1.0b 12/07/2010 by Lyonel Barthe
-- Changed coding style
--
-- Version 1.0a 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.2 8/04/2010 by Lyonel barthe
-- Clean Up Version
--
-- Version 0.1 1/12/2009 by Lyonel Barthe
-- Initial release
--

library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tool_lib;
use tool_lib.math_pack.all;

library soc_lib;
use soc_lib.uart_pack.all;

--
--! The module implements a small 8-N-1 UART controller without 
--! a frame error management. Rx and Tx data are not buffered 
--! (no double buffers / no FIFOs). The baud rate of the UART is 
--! nevertheless configurable through VHDL generics. Note that 
--! the user is in charge of assigning valid baud rate modes.
--

--! UART Controller Entity
entity uart_controller is
  
  port 
    ( 
      rx_i       : in std_ulogic;   --! rx input
      tx_o       : out std_ulogic;  --! tx output
      tx_dat_i   : in uart_data_t;  --! tx data to send
      rx_dat_o   : out uart_data_t; --! rx data received
      tx_send_i  : in std_ulogic;   --! start tx com
      tx_busy_o  : out std_ulogic;  --! tx com busy flag
      rx_ready_o : out std_ulogic;  --! rx com ready flag
      clk_i      : in std_ulogic;   --! controller clock
      rst_n_i    : in std_ulogic    --! active-low reset signal
    );
  
end uart_controller;

--! UART IP Architecture
architecture be_uart_controller of uart_controller is
  
  -- /////////////////////////////////////////////// 
  --                  INTERNAL REGS
  -- /////////////////////////////////////////////// 
  
  signal rx_baud_counter_r   : rx_baud_counter_t;   --! rx baud counter reg
  signal tx_baud_counter_r   : tx_baud_counter_t;   --! tx baud counter reg
  signal rx_baud_clk_r       : std_ulogic;          --! rx baud clk reg
  signal tx_baud_clk_r       : std_ulogic;          --! tx baud clk reg
  signal tx_count_r          : uart_data_counter_t; --! tx data counter reg
  signal rx_count_r          : uart_data_counter_t; --! rx data counter reg
  signal rx_i_r              : std_ulogic;          --! rx buffer reg
  signal rx_i_sync_r         : std_ulogic;          --! rx sync reg
  signal tx_o_r              : std_ulogic;          --! tx buffer reg
  signal rx_ready_r          : std_ulogic;          --! rx ready flag reg
  signal tx_busy_r           : std_ulogic;          --! tx busy flag reg
  signal rx_shift_r          : uart_data_t;         --! rx shift reg
  signal tx_shift_r          : uart_data_t;         --! tx shift reg
  signal rx_current_state_r  : rx_fsm_t;            --! rx fsm reg
  signal tx_current_state_r  : tx_fsm_t;            --! tx fsm reg

  -- force the synthesizer to pack UART interface registers into IOB 
  attribute iob: string;
  attribute iob of rx_i_r    : signal is "true";
  attribute iob of tx_o_r    : signal is "true";
  
  -- /////////////////////////////////////////////// 
  --                 INTERNAL WIRES
  -- ///////////////////////////////////////////////
  
  signal tx_s                : std_ulogic;
  signal tx_busy_s           : std_ulogic;
  signal tx_load_data_s      : std_ulogic;
  signal rx_ready_s          : std_ulogic;
  signal rx_shift_data_s     : std_ulogic;
  signal tx_shift_data_s     : std_ulogic;
  signal rx_rst_counters_s   : std_ulogic; 
  signal tx_rst_counters_s   : std_ulogic;
  signal rx_next_state_s     : rx_fsm_t;
  signal tx_next_state_s     : tx_fsm_t;
	
begin

  -- /////////////////////////////////////////////// 
  --                  COMB PROCESS
  -- /////////////////////////////////////////////// 
  
  --
  -- ASSIGN OUTPUT SIGNALS
  --

  rx_dat_o   <= rx_shift_r;
  tx_o       <= tx_o_r;
  tx_busy_o  <= tx_busy_r;
  rx_ready_o <= rx_ready_r;
 
  --
  -- TX COMB LOGIC
  --
  --! This process implements the control logic of the TX fsm.
  COMB_UART_TX_FSM: process(tx_current_state_r,
                            tx_baud_clk_r,
                            tx_shift_r,
                            tx_send_i,
                            tx_count_r)
    
  begin
    
    -- default assignments 
    -- improve code density and avoid latches
    tx_next_state_s   <= tx_current_state_r;
    tx_load_data_s    <= '0';
    tx_s              <= '1';
    tx_shift_data_s   <= '0';
    tx_busy_s         <= '0';
    tx_rst_counters_s <= '0';

    case tx_current_state_r is 
      
      -- wait to send
      when TX_IDLE =>
        -- reset counters
        tx_rst_counters_s <= '1';
        
        -- send data
        if(tx_send_i = '1') then
          tx_busy_s        <= '1';
          tx_load_data_s   <= '1';
          tx_next_state_s  <= TX_START;		
        end if;
        
      -- send start bit
      when TX_START =>
        tx_busy_s          <= '1';
        tx_s               <= '0'; -- start bit
        
        if(tx_baud_clk_r ='1') then
          tx_next_state_s  <= TX_SEND;
        end if;
        
      -- send data
      when TX_SEND =>
        tx_busy_s           <= '1';
        tx_s                <= tx_shift_r(0); -- lsb first
        
        if(tx_baud_clk_r ='1') then
          tx_shift_data_s   <= '1';
          
          -- end of tx com
          if(unsigned(tx_count_r) = (uart_data_t'length - 1)) then
            tx_next_state_s <= TX_STOP;
          end if;
          
        end if;
        
      -- send stop bit
      when TX_STOP =>
        tx_busy_s           <= '1';
        tx_s                <= '1'; -- stop bit
        
        if(tx_baud_clk_r ='1') then
          tx_next_state_s   <= TX_IDLE;
        end if;
        
      when others =>
        tx_next_state_s <= TX_IDLE; -- force a reset / safe implementation
        report "uart's tx fsm process: illegal state" severity warning;

    end case;
    
  end process COMB_UART_TX_FSM; 

  --
  -- RX COMB LOGIC
  --
  --! This process implements the control logic of the RX fsm. 
  COMB_UART_RX_FSM: process(rx_current_state_r,
                            rx_baud_clk_r,
                            rx_count_r,
                            rx_i_sync_r)
      
  begin
    
    -- default assignments 
    -- improve code density and avoid latches
    rx_next_state_s   <= rx_current_state_r;
    rx_ready_s        <= '0';
    rx_shift_data_s   <= '0';
    rx_rst_counters_s <= '0';
    
    case rx_current_state_r is 
      
      -- wait a start bit
      when RX_IDLE =>
        -- reset counters
        rx_rst_counters_s <= '1'; 
        
        if(rx_i_sync_r = '0') then -- start bit
          rx_next_state_s <= RX_START;
        end if;

      -- start bit
      when RX_START =>
        if(rx_baud_clk_r ='1') then
          -- check valid start bit data
          if (rx_i_sync_r = '0') then
            rx_next_state_s <= RX_SYNC;
          else
            rx_next_state_s <= RX_IDLE; -- error / not managed / force a reset
          end if;
          
        end if;
        
      -- data sync
      when RX_SYNC =>
        if(rx_baud_clk_r ='1') then
          rx_next_state_s <= RX_SHIFT;
        end if;
        
      -- shift data
      when RX_SHIFT =>
        if(rx_baud_clk_r ='1') then
          rx_shift_data_s     <= '1';
          
          if(unsigned(rx_count_r) = (uart_data_t'length - 1)) then
            rx_next_state_s   <= RX_STOP;
            
          else
            rx_next_state_s   <= RX_SYNC;
            
          end if;	
          
        end if;
        
      -- stop bit
      when RX_STOP =>
          if(rx_baud_clk_r ='1') then
            -- valid stop bit
            if(rx_i_sync_r = '1') then
              rx_next_state_s  <= RX_IDLE;
              rx_ready_s       <= '1'; -- set ready flag
         
              -- error / not managed / force a reset
            else
              rx_next_state_s <= RX_IDLE;        

            end if;

          end if;
        
      when others =>
        rx_next_state_s <= RX_IDLE; -- force a reset / safe implementation
        report "uart's rx fsm process: illegal state" severity warning;

    end case; 
    
  end process COMB_UART_RX_FSM;
	
  -- /////////////////////////////////////////////// 
  --                  CYCLE PROCESS
  -- /////////////////////////////////////////////// 

  --
  -- TX CLOCK GENERATOR
  --
  --! This process implements the tx baud pulse generator.  
  CYCLE_UART_TX_CLOCK: process(clk_i)	
  begin
      
    -- clock event
    if(clk_i'event and clk_i = '1') then	

      -- sync reset
      if(rst_n_i = '0' or tx_rst_counters_s = '1') then
        tx_baud_clk_r     <= '0';
        tx_baud_counter_r <= (others =>'0');
        
      elsif(unsigned(tx_baud_counter_r) = TX_BAUD_COUNTER_S) then
        tx_baud_clk_r     <= '1';
        tx_baud_counter_r <= (others =>'0');
        
      else
        tx_baud_clk_r     <= '0';
        tx_baud_counter_r <= std_ulogic_vector(unsigned(tx_baud_counter_r) + 1);
        
      end if;

    end if;
    
  end process CYCLE_UART_TX_CLOCK;

  --
  -- RX CLOCK GENERATOR
  --
  --! This process implements the rx baud pulse generator.  
  CYCLE_UART_RX_CLOCK: process(clk_i)	
  begin
      
    -- clock event
    if(clk_i'event and clk_i = '1') then	

      -- sync reset
      if(rst_n_i = '0' or rx_rst_counters_s = '1') then
        rx_baud_clk_r     <= '0';
        rx_baud_counter_r <= (others =>'0');
        
      elsif(unsigned(rx_baud_counter_r) = RX_BAUD_COUNTER_S) then
        rx_baud_clk_r     <= '1';
        rx_baud_counter_r <= (others =>'0');
        
      else
        rx_baud_clk_r     <= '0';
        rx_baud_counter_r <= std_ulogic_vector(unsigned(rx_baud_counter_r) + 1);
        
      end if;
       
    end if;
    
  end process CYCLE_UART_RX_CLOCK;
	
  --
  -- TX/RX FSM 
  --
  --! This process implements the rx & tx fsm reg.
  CYCLE_UART_FSM: process(clk_i)		
  begin
        
    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      -- sync reset
      if(rst_n_i = '0') then
        tx_current_state_r <= TX_IDLE;
        rx_current_state_r <= RX_IDLE;
        
      else
        tx_current_state_r <= tx_next_state_s;
        rx_current_state_r <= rx_next_state_s;
        
      end if;

    end if;
    
  end process CYCLE_UART_FSM;

  --
  -- TX SHIFT REG
  --
  --! This process implements the tx shift reg.
  CYCLE_UART_TX_SHIFT_REG: process(clk_i)		
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then
        
      if(tx_load_data_s = '1') then
        tx_shift_r <= tx_dat_i;
        
      elsif(tx_shift_data_s = '1') then
        tx_shift_r <= '0' & tx_shift_r(uart_data_t'length - 1 downto 1);
        
      end if;
   
    end if;
    
  end process CYCLE_UART_TX_SHIFT_REG;

  --
  -- RX SHIFT REG
  --
  --! This process implements the rx shift reg.
  CYCLE_UART_RX_SHIFT_REG: process(clk_i)		
  begin
          
    -- clock event
    if(clk_i'event and clk_i = '1') then

      if(rx_shift_data_s = '1') then
        rx_shift_r <= rx_i_sync_r & rx_shift_r(uart_data_t'length - 1 downto 1);
      end if;
        
    end if;    
    
  end process CYCLE_UART_RX_SHIFT_REG;
  
  --
  -- RX DATA COUNTER
  --
  --! This process implements the rx data counter for the serialization process.
  CYCLE_UART_RX_DATA_COUNTER: process(clk_i)		
  begin  
      
    -- clock event
    if(clk_i'event and clk_i = '1') then
     
      -- sync reset
      if(rst_n_i = '0' or rx_rst_counters_s = '1') then
        rx_count_r <= (others =>'0');
        
      elsif(rx_shift_data_s = '1') then
        rx_count_r <= std_ulogic_vector(unsigned(rx_count_r) + 1);
        
      end if;

    end if;
    
  end process CYCLE_UART_RX_DATA_COUNTER;

  --
  -- TX DATA COUNTER
  --
  --! This process implements the tx data counter for the serialization process.
  CYCLE_UART_TX_DATA_COUNTER: process(clk_i)		
  begin  
      
    -- clock event
    if(clk_i'event and clk_i = '1') then
     
      -- sync reset
      if(rst_n_i = '0' or tx_rst_counters_s = '1') then
        tx_count_r <= (others =>'0');
        
      elsif(tx_shift_data_s = '1') then
        tx_count_r <= std_ulogic_vector(unsigned(tx_count_r) + 1); 
        
      end if;

    end if;
    
  end process CYCLE_UART_TX_DATA_COUNTER;
   
  --
  -- RX SYNCHRONIZER REGISTERS
  --
  --! This cycle process implement synchronizer registers for the rx input.
  CYCLE_UART_RX_SYNC: process(clk_i)		
  begin
      
    -- clock event
    if(clk_i'event and clk_i = '1') then	

      -- sync reset
      if(rst_n_i = '0') then
        rx_i_r      <= '1';
        rx_i_sync_r <= '1';
        
      else
        rx_i_r      <= rx_i;	
        rx_i_sync_r <= rx_i_r;	
        
      end if;

    end if;
    
  end process CYCLE_UART_RX_SYNC;

  --
  -- TX REGISTERED OUTPUT
  --
  --! This cycle process implement tx output register.
  CYCLE_UART_TX_OUT_REG: process(clk_i)		
  begin
      
    -- clock event
    if(clk_i'event and clk_i = '1') then	

      -- sync reset
      if(rst_n_i = '0') then
        tx_o_r <= '1';
        
      else
        tx_o_r <= tx_s;	
        
      end if;

    end if;
    
  end process CYCLE_UART_TX_OUT_REG;
  
  --
  -- RX READY FLAG
  --
  --! This process implements the ready flag reg, required to provide 
  --! the end of the rx mode.
  CYCLE_UART_RX_READY: process(clk_i)		
  begin
       
    -- clock event
    if(clk_i'event and clk_i = '1') then	

      -- sync reset
      if(rst_n_i= '0') then
        rx_ready_r <= '0';
        
      else
        rx_ready_r <= rx_ready_s;	
        	
      end if;

    end if; 
    
  end process CYCLE_UART_RX_READY;

  --
  -- TX BUSY FLAG
  --
  --! This process implements the tx busy flag.
  CYCLE_UART_TX_BUSY: process(clk_i)		
  begin
       
    -- clock event
    if(clk_i'event and clk_i = '1') then	

      -- sync reset
      if(rst_n_i= '0') then
        tx_busy_r <= '0';
        
      else
        tx_busy_r <= tx_busy_s;		
        
      end if;

    end if; 
    
  end process CYCLE_UART_TX_BUSY;
	
end be_uart_controller;

