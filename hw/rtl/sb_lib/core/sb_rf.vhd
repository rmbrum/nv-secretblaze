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
--! @file sb_rf.vhd                                         					
--! @brief SecretBlaze Register File              				
--! @author Lyonel Barthe
--! @version 1.2
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.2 15/02/2011 by Lyonel Barthe
-- Removed bypassing for read operations (not used anymore)
-- Re-added optional BRAM template
--
-- Version 1.1 4/02/2011 by Lyonel Barthe
-- Standard RF implementation 
-- Removed optional BRAM template
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.2 7/04/2010 by Lyonel Barthe
-- Clean up version 
--
-- Version 0.1 15/02/2010 by Lyonel Barthe
-- Initial release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;
use sb_lib.sb_isa.all;

library config_lib;
use config_lib.sb_config.all;

--
--! The entity implements the Register File (RF) of the processor.
--! This is a classic RF implementing 32x32-bit registers. It can 
--! perform 1 synchronous write and 3 synchronous read operations 
--! during one clock cycle. 
--

--! 32-bit RISC Register File Entity 
entity sb_rf is

  generic
    (
      RF_TYPE     : string := USER_RF_TYPE
    );
  port
    (
      rf_i        : in rf_i_t;     --! register file inputs
      rf_o        : out rf_o_t;    --! register file outputs
      halt_core_i : in std_ulogic; --! halt core signal 
      stall_i     : in std_ulogic; --! stall signal (decode stage)
      clk_i       : in std_ulogic  --! core clock
    );

end sb_rf;

--! 32-bit RISC Register File Architecture 
architecture be_sb_rf of sb_rf is
  
  -- //////////////////////////////////////////
  --                INTERNAL REGS
  -- //////////////////////////////////////////     
  
  signal data_ra_r : data_t; --! first read buffer 
  signal data_rb_r : data_t; --! second read buffer 
  signal data_rd_r : data_t; --! last read buffer 
  
  -- //////////////////////////////////////////
  --                    RAM
  -- //////////////////////////////////////////

  signal reg_file_r : reg_file_t :=
    (0 => std_ulogic_vector(to_unsigned(0,data_t'length)), -- R0 must be initialized to '0'
                               others => (others => 'X')); --! 32x32 bit RAM implementing the RF   

  -- set implementation style
  attribute ram_style: string;
  attribute ram_style of reg_file_r : signal is RF_TYPE;
  
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --
  
  rf_o.dat_ra_o <= data_ra_r;
  rf_o.dat_rb_o <= data_rb_r;
  rf_o.dat_rd_o <= data_rd_r;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- REGISTER FILE SYNCHRONOUS WRITE 
  --
  --! This cycle process implements the behaviour
  --! of a synchronous write operation into the RF.
  CYCLE_WRITE_REG_FILE: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- write enable
      if(halt_core_i = '0' and rf_i.we_i = '1') then                                    
        reg_file_r(to_integer(unsigned(rf_i.adr_wr_i))) <= rf_i.dat_i;
      end if;
      
    end if;

  end process CYCLE_WRITE_REG_FILE;
  
  -- 
  -- REGISTER FILE SYNCHRONOUS READ 
  --
  --! This process implements the read buffers of the RF.
  CYCLE_READ_REG_FILE: process(clk_i)
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then
      
      -- read enable
      if(halt_core_i = '0' and stall_i = '0') then
        data_ra_r <= reg_file_r(to_integer(unsigned(rf_i.adr_ra_i)));
        data_rb_r <= reg_file_r(to_integer(unsigned(rf_i.adr_rb_i)));
        data_rd_r <= reg_file_r(to_integer(unsigned(rf_i.adr_rd_i)));
      end if;
      
    end if;
    
  end process CYCLE_READ_REG_FILE;
  
end be_sb_rf;   
   
