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
--! @file dpram4x8.vhd                                          					
--! @brief 4x8-bit Dual Port Synchronous Random Access Memory 
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
-- Version 0.2 7/04/2010 by Lyonel Barthe
-- Clean Up Version
--
-- Version 0.1 15/02/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;       
use std.textio.all;                  

library tool_lib;
use tool_lib.math_pack.all;

--
--! The entity implements a standard 4x8-bit Single Port
--! Dual Port Random Access Memory (DPRAM).
--! A file is use to initialize the content of the RAM.
--

--! Standard 4x8 DPRAM Entity 
entity dpram4x8 is

  generic
    (    
      RAM_TYPE   : string  := "block";                                  --! DPRAM implementation type
      MEM_FILE_1 : string  := "data_mem1.data";                         --! DPRAM source file LSB (bin/char format)
      MEM_FILE_2 : string  := "data_mem2.data";                         --! DPRAM source file (bin/char format)
      MEM_FILE_3 : string  := "data_mem3.data";                         --! DPRAM source file (bin/char format)
      MEM_FILE_4 : string  := "data_mem4.data";                         --! DPRAM source file MSB (bin/char format)
      RAM_WORD_S : natural := 2048                                      --! DPRAM word size
    );
   
  port
    (
      ena_i      : in std_ulogic;                                       --! DPRAM enable signal
      we_i       : in std_ulogic_vector(3 downto 0);                    --! DPRAM write enable signal
      adr_1_i    : in std_ulogic_vector(log2(RAM_WORD_S) - 1 downto 0); --! DPRAM primary address 
      adr_2_i    : in std_ulogic_vector(log2(RAM_WORD_S) - 1 downto 0); --! DPRAM secondary address
      dat_i      : in std_ulogic_vector(31 downto 0);                   --! DPRAM data to write
      dat_1_o    : out std_ulogic_vector(31 downto 0);                  --! DPRAM primary data read 
      dat_2_o    : out std_ulogic_vector(31 downto 0);                  --! DPRAM secondary data read 
      clk_i      : in std_ulogic                                        --! DPRAM clock
    );

end dpram4x8;

--! Standard 4x8 DPRAM Architecture 
architecture be_dpram4x8 of dpram4x8 is

begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////
  
  MEM_1 : entity tool_lib.dpram(be_dpram)
    generic map
    (
      RAM_TYPE => RAM_TYPE,
      MEM_FILE => MEM_FILE_1,
      RAM_W    => 8,
      RAM_S    => RAM_WORD_S
    )
    port map
    (
      ena_i    => ena_i,
      we_i     => we_i(0),
      adr_1_i  => adr_1_i,
      adr_2_i  => adr_2_i,
      dat_i    => dat_i(7 downto 0),
      dat_1_o  => dat_1_o(7 downto 0),
      dat_2_o  => dat_2_o(7 downto 0),
      clk_i    => clk_i  
    );
  
  MEM_2 : entity tool_lib.dpram(be_dpram)
    generic map
    (
      RAM_TYPE => RAM_TYPE,
      MEM_FILE => MEM_FILE_2,
      RAM_W    => 8,
      RAM_S    => RAM_WORD_S
    )
    port map
    (
      ena_i    => ena_i,
      we_i     => we_i(1),
      adr_1_i  => adr_1_i,
      adr_2_i  => adr_2_i,
      dat_i    => dat_i(15 downto 8),
      dat_1_o  => dat_1_o(15 downto 8),
      dat_2_o  => dat_2_o(15 downto 8),
      clk_i    => clk_i 
    );
  
  MEM_3 : entity tool_lib.dpram(be_dpram)
    generic map
    (
      RAM_TYPE => RAM_TYPE,
      MEM_FILE => MEM_FILE_3,
      RAM_W    => 8,
      RAM_S    => RAM_WORD_S
    )
    port map
    (
      ena_i    => ena_i,
      we_i     => we_i(2),
      adr_1_i  => adr_1_i,
      adr_2_i  => adr_2_i,
      dat_i    => dat_i(23 downto 16),
      dat_1_o  => dat_1_o(23 downto 16),
      dat_2_o  => dat_2_o(23 downto 16),
      clk_i    => clk_i   
    );
  
  MEM_4 : entity tool_lib.dpram(be_dpram)
    generic map
    (
      RAM_TYPE => RAM_TYPE,
      MEM_FILE => MEM_FILE_4,
      RAM_W    => 8,
      RAM_S    => RAM_WORD_S
    )
    port map
    (
      ena_i    => ena_i,
      we_i     => we_i(3),
      adr_1_i  => adr_1_i,
      adr_2_i  => adr_2_i,
      dat_i    => dat_i(31 downto 24),
      dat_1_o  => dat_1_o(31 downto 24),
      dat_2_o  => dat_2_o(31 downto 24),
      clk_i    => clk_i  
    );
  
end be_dpram4x8;

