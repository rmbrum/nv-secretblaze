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
--! @file dpram_0.vhd                                              					
--! @brief Dual-Port RAM with Synchronous Read/Write 
--! @author Lyonel Barthe
--! @version 1.1
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.1 12/2011 by Lyonel Barthe
-- Added check_x function to remove a simulation warning
--
-- Version 1.0 18/05/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tool_lib;
use tool_lib.math_pack.all;

--
--! The entity implements a standard dual-port RAM
--! with synchronous read/write using read first mode.
--

--! Standard DPRAM Entity
entity dpram_0 is

  generic
    (
      RAM_W   : natural := 32;                                  --! DPRAM data width 
      RAM_S   : natural := 32                                   --! DPRAM size
    );
  
  port
    (
      ena_i   : in std_ulogic;                                  --! DPRAM enable signal
      we_i    : in std_ulogic;                                  --! DPRAM write enable signal
      adr_1_i : in std_ulogic_vector(log2(RAM_S) - 1 downto 0); --! DPRAM primary address 
      adr_2_i : in std_ulogic_vector(log2(RAM_S) - 1 downto 0); --! DPRAM secondary address
      dat_i   : in std_ulogic_vector(RAM_W - 1 downto 0);       --! DPRAM data to write
      dat_1_o : out std_ulogic_vector(RAM_W - 1 downto 0);      --! DPRAM primary data read 
      dat_2_o : out std_ulogic_vector(RAM_W - 1 downto 0);      --! DPRAM secondary data read 
      clk_i   : in std_ulogic                                   --! DPRAM clock
    );

end dpram_0;

--! Standard DPRAM Architecture
architecture be_dpram_0 of dpram_0 is

  --! DPRAM type 
  type dpram_t is array(0 to RAM_S - 1) of std_ulogic_vector(RAM_W - 1 downto 0);
  
  -- //////////////////////////////////////////
  --                    RAM
  -- //////////////////////////////////////////

  signal dpram_r : dpram_t := (others => (others => '0')); --! DPRAM object

begin
  
  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- SYNCHRONOUS WRITE & READ
  --
  --! This process implements the behaviour
  --! of a dual-port RAM.
  CYCLE_DPRAM : process(clk_i)
  begin

    if(clk_i'event and clk_i = '1') then
      
      -- ram enable
      if(ena_i = '1') then 

        -- write enable
        if (we_i = '1') then
          dpram_r(to_integer(unsigned(check_x(adr_1_i)))) <= dat_i;
        end if;
		
        -- read first mode
        dat_1_o <= dpram_r(to_integer(unsigned(check_x(adr_1_i)))); 
        dat_2_o <= dpram_r(to_integer(unsigned(check_x(adr_2_i)))); 
		
      end if;
    end if;
    
  end process CYCLE_DPRAM;

end be_dpram_0;

