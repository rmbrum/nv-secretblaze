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
--! @file timer_slave_wb_bus.vhd                                					
--! @brief TIMER Controller and its WISHBONE Bus Slave Interface     				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 10/05/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb_lib;
use wb_lib.wb_pack.all;

library soc_lib;
use soc_lib.timer_pack.all;

--
--! The module implements a basic TIMER IP and its WISHBONE
--! bus slave interface. It supports pipelined read/write mode.
--

--! TIMER & WISHBONE Bus Slave Interface Entity
entity timer_slave_wb_bus is

  port
    (
      -- data & control signals
      timer_int_o : out timer_int_vector_t; --! TIMER interrupt vector output
      wb_bus_i    : in wb_slave_bus_i_t;    --! WISHBONE slave inputs
      wb_bus_o    : out wb_slave_bus_o_t    --! WISHBONE slave outputs  
    );

end timer_slave_wb_bus;

--! TIMER & WISHBONE Bus Slave Interface Architecture
architecture be_timer_slave_wb_bus of timer_slave_wb_bus is
  
  -- //////////////////////////////////////////
  --                INTERNAL REGS
  -- //////////////////////////////////////////

  -- Nota: UNUSED BIT WON'T BE IMPLEMENTED!
  -- in order to save FFs.

  -- control_1_r : BASE_ADDRESS + 0x0 (write only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31           ...     |    1 |  0 |
  -- +-------------------------------------+
  -- |               unused    | rst  | en |
  -- +-------------------------------------+
  signal control_1_r    : std_ulogic_vector(1 downto 0);  --! control reg (first counter)
   
  -- threshold_1_r : BASE_ADDRESS + 0x4 (read/write)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31           ...               0 |
  -- +-------------------------------------+
  -- |            threshold value          |
  -- +-------------------------------------+
  signal threshold_1_r  : timer_data_t;                   --! threshold reg (first counter)
                                                                 
  -- counter_1_r : BASE_ADDRESS + 0x8 (read only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31           ...               0 |
  -- +-------------------------------------+
  -- |             counter value           |
  -- +-------------------------------------+
  signal counter_1_r   : timer_data_t;                    --! first counter reg 
  
  -- control_2_r : BASE_ADDRESS + 0xc (write only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31           ...     |    1 |  0 |
  -- +-------------------------------------+
  -- |               unused    | rst  | en |
  -- +-------------------------------------+
  signal control_2_r    : std_ulogic_vector(1 downto 0);  --! control reg (second counter)
   
  -- threshold_2_r : BASE_ADDRESS + 0x10 (read/write)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31           ...               0 |
  -- +-------------------------------------+
  -- |            threshold value          |
  -- +-------------------------------------+
  signal threshold_2_r  : timer_data_t;                   --! threshold reg (second counter)
                                                                 
  -- counter_2_r : BASE_ADDRESS + 0x14 (read only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31           ...               0 |
  -- +-------------------------------------+
  -- |             counter value           |
  -- +-------------------------------------+
  signal counter_2_r   : timer_data_t;                    --! second counter reg
                                                                          
  signal wb_ack_o_r    : std_ulogic;                                      --! WISHBONE ack reg
  signal wb_dat_o_r    : std_ulogic_vector(MAX_SLV_TIMER_W - 1 downto 0); --! WISHBONE data bus reg
  signal timer_event_r : timer_int_vector_t;                              --! TIMER event reg

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////
  
  --
  -- SLAVE INTERFACE SIGNALS
  -- 
  
  signal slv_read_s              : wb_bus_data_t;
  signal slv_write_threshold_1_s : wb_bus_data_t;
  signal slv_write_control_1_s   : wb_bus_data_t;
  signal slv_write_threshold_2_s : wb_bus_data_t;
  signal slv_write_control_2_s   : wb_bus_data_t;

  --
  -- WB SIGNALS
  -- 

  signal wb_we_s                 : std_ulogic;
  signal wb_re_s                 : std_ulogic;
  signal wb_reg_adr_s            : wb_timer_reg_adr_t;
  signal wb_ack_s                : std_ulogic;

  --
  -- IP SIGNALS
  --

  signal counter_1_s             : timer_data_t;
  signal counter_2_s             : timer_data_t;
  signal timer_1_event_s         : std_ulogic;
  signal timer_2_event_s         : std_ulogic;
     
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --
  
  wb_bus_o.ack_o   <= wb_ack_o_r;                                                                             
  wb_bus_o.dat_o   <= std_ulogic_vector(resize(unsigned(wb_dat_o_r),wb_bus_data_t'length));
  wb_bus_o.err_o   <= '0'; -- not implemented
  wb_bus_o.rty_o   <= '0'; -- not implemented
  wb_bus_o.stall_o <= '0'; -- not implemented 
  timer_int_o      <= timer_event_r; -- TIMER interrupt vector

  --
  -- ASSIGN INTERNAL SIGNALS
  --
  
  --
  -- WB SIGNALS
  --
 
  wb_we_s      <= (wb_bus_i.stb_i and wb_bus_i.cyc_i and wb_bus_i.we_i);                                    -- write bus operation          
  wb_re_s      <= (wb_bus_i.stb_i and wb_bus_i.cyc_i and not(wb_bus_i.we_i));                               -- read bus operation 
  wb_reg_adr_s <= (wb_bus_i.adr_i(wb_timer_reg_adr_t'length + WB_WORD_ADR_OFF - 1 downto WB_WORD_ADR_OFF)); -- register address
  wb_ack_s     <= (wb_bus_i.stb_i and wb_bus_i.cyc_i);                                                      -- pipelined read/write ack

  --
  -- COMB TIMER 1
  --
  --! This process implements the behaviour of a basic timer. 
  --! When counter = threshold, it generates an interrupt.
  COMB_TIMER_1: process(counter_1_r,
                        threshold_1_r,
                        control_1_r)

  begin

    -- default
    counter_1_s     <= counter_1_r;
    timer_1_event_s <= '0';

    -- force reset
    if(control_1_r(1) = '1') then
      counter_1_s   <= (others =>'0');

      -- timer enabled
    elsif(control_1_r(0) = '1') then

      -- end of period
      if(counter_1_r = threshold_1_r) then
        counter_1_s     <= (others =>'0');
        timer_1_event_s <= '1';
        
      else
        counter_1_s     <= std_ulogic_vector(unsigned(counter_1_r) + 1);
        
      end if;

    end if;

  end process COMB_TIMER_1;
  
  --
  -- COMB TIMER 2
  --
  --! This process implements the behaviour of a basic timer.
  --! When counter = threshold, it generates an interrupt.
  COMB_TIMER_2: process(counter_2_r,
                        threshold_2_r,
                        control_2_r)

  begin

    -- default
    counter_2_s     <= counter_2_r;
    timer_2_event_s <= '0';

    -- force reset
    if(control_2_r(1) = '1') then
      counter_2_s   <= (others =>'0');

      -- timer enabled
    elsif(control_2_r(0) = '1') then

      -- end of period
      if(counter_2_r = threshold_2_r) then
        counter_2_s     <= (others =>'0');
        timer_2_event_s <= '1';
        
      else
        counter_2_s     <= std_ulogic_vector(unsigned(counter_2_r) + 1);
        
      end if;

    end if;

  end process COMB_TIMER_2;

  --
  -- COMB SLAVE READ REG
  --
  --! This process implements the behaviour of a bus read operation.
  COMB_SLAVE_READ_REG: process(wb_bus_i,
                               threshold_1_r,
                               counter_1_r,
                               threshold_2_r,
                               counter_2_r,
                               wb_re_s,
                               wb_reg_adr_s)
    
    variable counter_1_v   : wb_bus_data_t;
    variable threshold_1_v : wb_bus_data_t;
    variable counter_2_v   : wb_bus_data_t;
    variable threshold_2_v : wb_bus_data_t;

  begin

    threshold_1_v := std_ulogic_vector(resize(unsigned(threshold_1_r),wb_bus_data_t'length));
    counter_1_v   := std_ulogic_vector(resize(unsigned(counter_1_r),wb_bus_data_t'length));
    threshold_2_v := std_ulogic_vector(resize(unsigned(threshold_2_r),wb_bus_data_t'length));
    counter_2_v   := std_ulogic_vector(resize(unsigned(counter_2_r),wb_bus_data_t'length));      

    -- default
    slv_read_s  <= (others =>'X');
    
    -- read enable
    if(wb_re_s = '1') then
      
      -- decode reg address 
      case wb_reg_adr_s is 
        
        when THRESHOLD_1_OFF =>
                    
          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= threshold_1_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when COUNTER_1_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= counter_1_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
       
        when THRESHOLD_2_OFF =>
                    
          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= threshold_2_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when COUNTER_2_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= counter_2_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when others =>
          report "timer's slave read process: illegal address" severity warning;
          
      end case;
      
    end if;

  end process COMB_SLAVE_READ_REG;
 
  --
  -- COMB SLAVE WRITE REG
  --
  --! This process implements the behaviour of a bus write operation.
  COMB_SLAVE_WRITE_REG: process(wb_bus_i,
                                control_1_r,
                                threshold_1_r,
                                control_2_r,
                                threshold_2_r,
                                wb_we_s,
                                wb_reg_adr_s)
  
  begin
    
    -- default 
    slv_write_threshold_1_s <= std_ulogic_vector(resize(unsigned(threshold_1_r),wb_bus_data_t'length));
    slv_write_control_1_s   <= std_ulogic_vector(resize(unsigned(control_1_r),wb_bus_data_t'length));  
    slv_write_threshold_2_s <= std_ulogic_vector(resize(unsigned(threshold_2_r),wb_bus_data_t'length));
    slv_write_control_2_s   <= std_ulogic_vector(resize(unsigned(control_2_r),wb_bus_data_t'length));  
    
    -- write enable
    if(wb_we_s = '1') then
      
      -- decode address 
      case wb_reg_adr_s is 
        
        when CONTROL_1_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_control_1_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;

        when THRESHOLD_1_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_threshold_1_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when CONTROL_2_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_control_2_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;

        when THRESHOLD_2_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_threshold_2_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when others =>
          report "timer's slave write process: illegal address" severity warning;
          
      end case;
      
    end if;

  end process COMB_SLAVE_WRITE_REG;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- WB SLAVE BUS REGISTERED OUTPUTS
  --
  --! This process implements WISHBONE slave output registers.
  CYCLE_TIMER_WB_OUT_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        wb_ack_o_r <= '0';
        
      else
        wb_ack_o_r <= wb_ack_s; 
        wb_dat_o_r <= slv_read_s(MAX_SLV_TIMER_W - 1 downto 0);
        
      end if;
      
    end if;

  end process CYCLE_TIMER_WB_OUT_REG;

  --
  -- WRITE BUFFERS
  --
  --! This process implements write only registers
  --! of the WISHBONE bus slave interface.
  CYCLE_WRITE_REG: process(wb_bus_i.clk_i)
  begin

    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        control_1_r <= (others =>'0');
        control_2_r <= (others =>'0');
                
      else
        control_1_r <= slv_write_control_1_s(1 downto 0);
        control_2_r <= slv_write_control_2_s(1 downto 0);
        
      end if;
      
    end if;

  end process CYCLE_WRITE_REG;
  
  --
  -- READ BUFFERS
  --
  --! This process implements read only registers
  --! of the WISHBONE bus slave interface.
  CYCLE_READ_REG: process(wb_bus_i.clk_i)
  begin

    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        counter_1_r <= (others =>'0');
        counter_2_r <= (others =>'0');
        
      else
        counter_1_r <= counter_1_s;
        counter_2_r <= counter_2_s; 
               
      end if;
      
    end if;

  end process CYCLE_READ_REG;
    
  --
  -- READ/WRITE BUFFERS
  --
  --! This process implements read/write registers
  --! of the WISHBONE bus slave interface.
  CYCLE_READ_WRITE_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        threshold_1_r <= (others =>'1');
        threshold_2_r <= (others =>'1');
                
      else
        threshold_1_r <= slv_write_threshold_1_s(TIMER_DATA_W - 1 downto 0);
        threshold_2_r <= slv_write_threshold_2_s(TIMER_DATA_W - 1 downto 0);
                
      end if;
      
    end if;

  end process CYCLE_READ_WRITE_REG;

  --
  -- TIMER EVENT REG
  --
  --! This process implements the timer event output register.
  CYCLE_TIMER_OUT_REG: process(wb_bus_i.clk_i)
  begin

    -- clock event
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        timer_event_r <= (others => '0');
        
      else
        timer_event_r <= (timer_2_event_s & timer_1_event_s);
        
      end if;
      
    end if;

  end process CYCLE_TIMER_OUT_REG;
  
end be_timer_slave_wb_bus;

