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
--! @file sb_dwb_interface.vhd                            					
--! @brief SecretBlaze Data WISHBONE Interface  				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 21/01/2012 by Lyonel Barthe
-- Initial release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;
use sb_lib.sb_memory_unit_pack.all;

library wb_lib;
use wb_lib.wb_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.sb_config.all;
use config_lib.soc_config.all;

--
--! The module implements the WISHBONE interface for data memory accesses.
--
  
--! SecretBlaze Data WISHBONE Interface Entity
entity sb_dwb_interface is

  generic
    (
      C_S_CLK_DIV     : real    := USER_C_S_CLK_DIV;  --! core/system clock ratio
      USE_DCACHE      : boolean := USER_USE_DCACHE;   --! if true, it will implement the data cache
      USE_WRITEBACK   : boolean := USER_USE_WRITEBACK --! if true, use write-back policy
    );

  port
    (
      dwb_bus_i       : in wb_master_bus_i_t;         --! data WISHBONE master bus inputs
      dwb_bus_o       : out wb_master_bus_o_t;        --! data WISHBONE master bus outputs
      dwb_grant_i     : in std_ulogic;                --! data WISHBONE grant signal input
      dm_io_bus_i     : in dm_bus_i_t;                --! data L1 bus inputs (io side)
      dm_io_bus_o     : out dm_bus_o_t;               --! data L1 bus outputs (io side)
      dc_bus_i        : in dc_bus_i_t;                --! data cache bus inputs
      dc_bus_o        : out dc_bus_o_t;               --! data cache bus outputs 
      dc_req_done_i   : in std_ulogic;                --! data cache request done flag
      dc_burst_done_i : in std_ulogic;                --! data cache burst done flag
      io_busy_o       : out std_ulogic;               --! io busy output signal
      halt_io_i       : in std_ulogic;                --! io unit stall control signal
      halt_core_i     : in std_ulogic;                --! core stall control signal
      clk_i           : in std_ulogic;                --! core clock
      rst_n_i         : in std_ulogic                 --! active-low reset signal 
    );

end sb_dwb_interface;

--! SecretBlaze Data WISHBONE Interface Architecture
architecture be_sb_dwb_interface of sb_dwb_interface is

  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////

  signal io_ena_r       : std_ulogic;    --! io ena reg
  signal io_dat_i_r     : dm_bus_data_t; --! io data input reg
  signal io_adr_r       : dm_bus_adr_t;  --! io address reg
  signal io_we_r        : std_ulogic;    --! io we reg
  signal io_sel_r       : dm_bus_sel_t;  --! io byte sel reg
  signal io_dat_o_r     : dm_bus_data_t; --! io buffer reg
  signal io_done_r      : std_ulogic;    --! io done flag reg
  signal io_sync_ack_r  : std_ulogic_vector(log2(natural(C_S_CLK_DIV)) - 1 downto 0); --! io sync ack reg
  signal dwb_io_cyc_o_r : std_ulogic;    --! data WISHBONE io cyc reg 
  signal dwb_io_stb_o_r : std_ulogic;    --! data WISHBONE io stb reg 
  signal dwb_io_sel_o_r : wb_bus_sel_t;  --! data WISHBONE io sel reg 
  signal dwb_io_dat_o_r : wb_bus_data_t; --! data WISHBONE io data out reg 
  signal dwb_io_adr_o_r : wb_bus_adr_t;  --! data WISHBONE io address reg 
  signal dwb_io_we_o_r  : std_ulogic;    --! data WISHBONE io wr control reg
  signal dwb_io_ack_i_r : std_ulogic;    --! data WISHBONE io ack reg
  signal dwb_c_cyc_o_r  : std_ulogic;    --! data WISHBONE cache cyc reg 
  signal dwb_c_stb_o_r  : std_ulogic;    --! data WISHBONE cache stb reg 
  signal dwb_c_dat_o_r  : wb_bus_data_t; --! data WISHBONE cache data out reg 
  signal dwb_c_adr_o_r  : wb_bus_adr_t;  --! data WISHBONE cache address reg 
  signal dwb_c_sel_o_r  : wb_bus_sel_t;  --! data WISHBONE cache sel reg (only if USE_WRITEBACK is false)
  signal dwb_c_we_o_r   : std_ulogic;    --! data WISHBONE cache wr control reg 
  signal dwb_c_cti_o_r  : wb_bus_cti_t;  --! data WISHBONE cache bus flag reg 
  signal dwb_c_ack_i_r  : std_ulogic;    --! data WISHBONE cache ack reg
  signal dwb_c_bl_o_r   : wb_bus_bl_t;   --! data WISHBONE cache burst length reg (only if USE_WRITEBACK is false)  
  signal dwb_dat_i_r    : wb_bus_data_t; --! data WISHBONE memory (shared by both io/dc) input reg

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  --
  -- IO SIGNALS
  --

  signal io_done_s      : std_ulogic;
  signal io_sync_ack_s  : std_ulogic;
  signal io_busy_s      : std_ulogic;
  signal dwb_io_cyc_o_s : std_ulogic;
  signal dwb_io_stb_o_s : std_ulogic;
    
  --
  -- WB INTERFACE SIGNALS
  --

  signal dwb_stb_o_s    : std_ulogic;
  signal dwb_sel_o_s    : wb_bus_sel_t; 
  signal dwb_dat_o_s    : wb_bus_data_t;
  signal dwb_adr_o_s    : wb_bus_adr_t;  
  signal dwb_we_o_s     : std_ulogic;  
  signal dwb_cti_o_s    : wb_bus_cti_t;  
  signal dwb_bte_o_s    : wb_bus_bte_t;  
  signal dwb_cyc_o_s    : std_ulogic;  
  signal dwb_bl_o_s     : wb_bus_bl_t;     

begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --

  --
  -- CONTROL SIGNAL
  --
 
  io_busy_o         <= io_busy_s;

  --
  -- WB -> MAIN MEMORY
  -- 

  dwb_bus_o.adr_o   <= dwb_adr_o_s;
  dwb_bus_o.sel_o   <= dwb_sel_o_s;
  dwb_bus_o.we_o    <= dwb_we_o_s;
  dwb_bus_o.stb_o   <= dwb_stb_o_s;
  dwb_bus_o.cyc_o   <= dwb_cyc_o_s;
  dwb_bus_o.dat_o   <= dwb_dat_o_s;
  dwb_bus_o.cti_o   <= dwb_cti_o_s;
  dwb_bus_o.bte_o   <= dwb_bte_o_s;
  dwb_bus_o.bl_o    <= dwb_bl_o_s;
  
  --
  -- WB -> CACHE
  --

  dc_bus_o.dat_o    <= dwb_dat_i_r;
  dc_bus_o.ack_o    <= dwb_c_ack_i_r;
  
  --
  -- IO -> L1 BUS
  --
  
  dm_io_bus_o.dat_o <= io_dat_o_r;
  
  --
  -- ASSIGN INTERNAL SIGNALS
  -- 

  --
  -- SYNC SIGNAL FOR CCLK = SCLK
  --

  GEN_IO_SYNC_ACK_NO_DIV: if(C_S_CLK_DIV = 1.0) generate
  begin

    io_sync_ack_s <= dwb_io_ack_i_r;

  end generate GEN_IO_SYNC_ACK_NO_DIV;

  --
  -- SYNC SIGNAL FOR CCLK > SCLK
  --

  GEN_IO_SYNC_ACK_DIV: if(C_S_CLK_DIV > 1.0) generate
  begin

    io_sync_ack_s <= '1' when to_integer(unsigned(io_sync_ack_r)) = (natural(C_S_CLK_DIV) - 1) else '0';

  end generate GEN_IO_SYNC_ACK_DIV;

  --
  -- DATA WB MASTER OUTPUT LOGIC
  --
  --! This process implements the data WISHBONE master output interface.
  --! Note that IO/DC busses are multiplexed.
  COMB_DATA_WB_OUT_LOGIC: process(dwb_c_stb_o_r,
                                  dwb_c_adr_o_r,
                                  dwb_c_sel_o_r,
                                  dwb_c_dat_o_r,
                                  dwb_c_cti_o_r,
                                  dwb_c_we_o_r,
                                  dwb_c_cyc_o_r,
                                  dwb_c_bl_o_r,
                                  dwb_io_stb_o_r,
                                  dwb_io_we_o_r,
                                  dwb_io_adr_o_r,
                                  dwb_io_dat_o_r,
                                  dwb_io_sel_o_r,
                                  dwb_io_cyc_o_r,
                                  dwb_bus_i,
                                  io_ena_r)
  begin

    dwb_bte_o_s     <= WB_LINEAR_BURST;

    -- cache access
    if(USE_DCACHE = true and io_ena_r = '0') then
      dwb_cyc_o_s   <= dwb_c_cyc_o_r;
      dwb_stb_o_s   <= dwb_c_stb_o_r;
      dwb_adr_o_s   <= dwb_c_adr_o_r;
      dwb_we_o_s    <= dwb_c_we_o_r;
      if(USE_WRITEBACK = true) then
        dwb_sel_o_s <= WB_WORD_SEL; 
        dwb_bl_o_s  <= std_ulogic_vector(to_unsigned((DC_LINE_WORD_S - 1),wb_bus_bl_t'length));          

      else
        dwb_sel_o_s <= dwb_c_sel_o_r;
        dwb_bl_o_s  <= dwb_c_bl_o_r;          

      end if;
      dwb_dat_o_s   <= dwb_c_dat_o_r;
      dwb_cti_o_s   <= dwb_c_cti_o_r;
    
      -- io access
    else
      dwb_cyc_o_s   <= dwb_io_cyc_o_r;
      dwb_stb_o_s   <= dwb_io_stb_o_r;
      dwb_adr_o_s   <= dwb_io_adr_o_r;
      dwb_we_o_s    <= dwb_io_we_o_r;
      dwb_sel_o_s   <= dwb_io_sel_o_r;
      dwb_dat_o_s   <= dwb_io_dat_o_r;
      dwb_cti_o_s   <= WB_CLASSIC_CYCLE;

    end if;

  end process COMB_DATA_WB_OUT_LOGIC;

  --
  -- DATA WB IO CONTROL LOGIC 
  --
  --! This process implements the control signals of
  --! the data WISHBONE interface for I/O accesses.
  COMB_DATA_WB_IO_MST_CONTROL_LOGIC: process(io_ena_r,
                                             io_done_r,
                                             io_sync_ack_s,
                                             dwb_bus_i,
                                             dwb_grant_i,
                                             dwb_io_cyc_o_r)

  begin

    -- finish a bus cycle 
    if(io_sync_ack_s = '1') then
      dwb_io_cyc_o_s <= '0';
      dwb_io_stb_o_s <= '0';
      io_busy_s      <= '1'; 
      io_done_s      <= '1'; 

      -- keep a bus cycle
    elsif(dwb_io_cyc_o_r = '1' and dwb_grant_i = '1') then
      dwb_io_cyc_o_s <= '1';
      dwb_io_stb_o_s <= '0';
      io_busy_s      <= '1'; 
      io_done_s      <= '0'; 

      -- start a bus cycle
    elsif(io_ena_r = '1' and io_done_r = '0') then
      dwb_io_cyc_o_s <= '1';
      dwb_io_stb_o_s <= '1';
      io_busy_s      <= '1'; 
      io_done_s      <= '0'; 

      -- idle state
    else
      dwb_io_cyc_o_s <= '0';
      dwb_io_stb_o_s <= '0';
      io_busy_s      <= '0'; 
      io_done_s      <= '0'; 

    end if;

  end process COMB_DATA_WB_IO_MST_CONTROL_LOGIC;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- CCLK CLOCK REGION
  --

  --
  -- IO L1 BUS REGISTERS
  --
  --! This process implements IO L1 bus input registers.
  --! Note that these registers are stalled as the core
  --! of the processor.
  CYCLE_IO_L1_IN_REG: process(clk_i)
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then
    
      -- sync reset
      if(rst_n_i = '0') then
        io_ena_r   <= '0';
        
      elsif(halt_core_i = '0') then
        io_ena_r   <= dm_io_bus_i.ena_i;
        io_sel_r   <= dm_io_bus_i.sel_i;
        io_dat_i_r <= dm_io_bus_i.dat_i;
        io_adr_r   <= dm_io_bus_i.adr_i;
        io_we_r    <= dm_io_bus_i.we_i;
        
      end if;

    end if;

  end process CYCLE_IO_L1_IN_REG;

  --
  -- IO BUFFER 
  --
  --! This process implements the IO data buffer.
  CYCLE_IO_BUFFER: process(clk_i)
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then
    
      if(halt_io_i = '0' and io_done_s = '1') then 
        io_dat_o_r <= dwb_dat_i_r;
      end if;

    end if;

  end process CYCLE_IO_BUFFER;

  --
  -- IO DONE REG
  --
  --! This process implements the IO done flag reg.
  CYCLE_IO_DONE_FLAG: process(clk_i)
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then
    
      -- sync reset
      if(rst_n_i = '0') then
        io_done_r <= '0';
        
      elsif(halt_io_i = '0') then
        io_done_r <= io_done_s;
        
      end if;

    end if;

  end process CYCLE_IO_DONE_FLAG;

  --
  -- CCLK > SCLK
  --

  GEN_CYCLE_IO_ACK_SYNC: if(C_S_CLK_DIV > 1.0) generate
  begin

    --
    -- SYNC IO ACK 
    --
    --! This process implements the I/O ack counter used to 
    --! synchronize the core clock with the bus clock.
    CYCLE_IO_ACK_SYNC: process(clk_i)
    begin
      
      -- clock event
      if(clk_i'event and clk_i = '1') then
      
        -- sync reset
        if(rst_n_i = '0') then
          io_sync_ack_r <= (others => '0');
          
        elsif(halt_io_i = '0' and dwb_io_ack_i_r = '1') then
          io_sync_ack_r <= std_ulogic_vector(unsigned(io_sync_ack_r) + 1);
          
        end if;

      end if;

    end process CYCLE_IO_ACK_SYNC;

  end generate GEN_CYCLE_IO_ACK_SYNC;

  --
  -- SCLK CLOCK REGION
  --

  --
  -- DATA WB MASTER BUS REGISTERED OUTPUTS 
  -- 
  --! This process implements data WISHBONE master output registers.
  CYCLE_DATA_WB_MST_OUT_REG: process(dwb_bus_i.clk_i)
  begin
    
    -- clock event
    if(dwb_bus_i.clk_i'event and dwb_bus_i.clk_i = '1') then
    
      -- sync reset
      if(dwb_bus_i.rst_i = '1') then
        dwb_io_cyc_o_r     <= '0';
        dwb_io_stb_o_r     <= '0';
        if(USE_DCACHE = true) then
          dwb_c_cyc_o_r    <= '0';
          dwb_c_stb_o_r    <= '0';
        end if;
        
      elsif(dwb_bus_i.stall_i = '0') then 
        dwb_io_cyc_o_r     <= dwb_io_cyc_o_s;
        dwb_io_stb_o_r     <= dwb_io_stb_o_s;
        dwb_io_sel_o_r     <= io_sel_r;
        dwb_io_adr_o_r     <= io_adr_r;
        dwb_io_we_o_r      <= io_we_r;
        dwb_io_dat_o_r     <= io_dat_i_r;
        if(USE_DCACHE = true) then
          dwb_c_stb_o_r    <= dc_bus_i.ena_i;
          dwb_c_adr_o_r    <= dc_bus_i.adr_i;
          dwb_c_we_o_r     <= dc_bus_i.we_i;
          dwb_c_dat_o_r    <= dc_bus_i.dat_i;
          if(dc_burst_done_i = '1') then
            dwb_c_cyc_o_r  <= '0';

          elsif(dwb_c_cyc_o_r = '0') then
            dwb_c_cyc_o_r  <= dc_bus_i.ena_i;

          end if;
          if(dc_burst_done_i = '1') then
            dwb_c_cti_o_r  <= WB_INC_BURST_CYCLE;

          elsif(dc_req_done_i = '1') then
            dwb_c_cti_o_r  <= WB_END_OF_BURST;

          else
            dwb_c_cti_o_r  <= WB_INC_BURST_CYCLE;

          end if;
          if(USE_WRITEBACK = false) then
            dwb_c_sel_o_r  <= dc_bus_i.sel_i;
            if(dc_bus_i.we_i = '0') then
              dwb_c_bl_o_r <= std_ulogic_vector(to_unsigned((DC_LINE_WORD_S - 1),wb_bus_bl_t'length)); 
              
            else
              dwb_c_bl_o_r <= (others => '0');       
                   
            end if;            
          end if;
        end if;
        
      end if;

    end if;

  end process CYCLE_DATA_WB_MST_OUT_REG;

  --
  -- DATA WB MASTER BUS REGISTERED INPUTS
  --
  --! This process implements data WISHBONE master input registers.
  CYCLE_DATA_WB_MST_IN_REG: process(dwb_bus_i.clk_i)
  begin
    
    -- clock event
    if(dwb_bus_i.clk_i'event and dwb_bus_i.clk_i = '1') then
    
      -- sync reset
      if(dwb_bus_i.rst_i = '1') then
        dwb_io_ack_i_r   <= '0';
        if(USE_DCACHE = true) then
          dwb_c_ack_i_r  <= '0';
        end if;
        
      else
        dwb_dat_i_r      <= dwb_bus_i.dat_i;
        if(dwb_io_cyc_o_r = '1') then 
          dwb_io_ack_i_r <= dwb_bus_i.ack_i;
        end if;
        if(USE_DCACHE = true and dwb_c_cyc_o_r = '1') then 
          dwb_c_ack_i_r  <= dwb_bus_i.ack_i;
        end if;
        
      end if;

    end if;
    
  end process CYCLE_DATA_WB_MST_IN_REG;
    
end be_sb_dwb_interface;

