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
--! @file async_ram.vhd                                         					
--! @brief Asynchronous SRAM         				
--! @author Lyonel Barthe
--! @version 1.1
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.1 23/12/2010 by Lyonel Barthe
-- Byte sel read/write support
--
-- Version 1.0 22/09/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

library sb_lib;
use sb_lib.sb_core_pack.all;
use sb_lib.sb_isa.all;

library tool_lib;
use tool_lib.math_pack.all;

--
--! The entity implements an asynchronous SRAM for simulation
--! purpose only. RAM timings are not taken into account.
--

--! Asynchronous SRAM Entity
entity async_sram is
  
  generic
    (
      MEM_FILE : string  := "data_file.data";                    --! SRAM source file (bin/char format)
      RAM_W    : natural := 32;                                  --! SRAM data width 
      RAM_S    : natural := 32                                   --! SRAM size
    );

  port
    (
      ce_n_i   : in std_ulogic;                                  --! SRAM active-low chip enable signal 
      we_n_i   : in std_ulogic;                                  --! SRAM active-low write enable signal
      sel_n_i  : in std_ulogic_vector(RAM_W/8 - 1 downto 0);     --! SRAM active-low byte sel signal
      oe_n_i   : in std_ulogic;                                  --! SRAM active-low output enable signal
      a_i      : in std_ulogic_vector(log2(RAM_S) - 1 downto 0); --! SRAM address signal
      data_io  : inout std_logic_vector(RAM_W - 1 downto 0);     --! SRAM read/write data
      clk_i    : in std_ulogic                                   --! memory clock
    );
  
end async_sram;

--! Asynchronous SRAM Architecture
architecture be_async_sram of async_sram is

  --! ASRAM type 
  type asram_t is array(0 to RAM_S - 1) of std_logic_vector(RAM_W - 1 downto 0);

  -- //////////////////////////////////////////
  --                FILE UTIL
  -- //////////////////////////////////////////
  
  --! File loader function
  impure function init_from_file(file_name : in string) return asram_t is

    file ram_file_f           : text;                       
    variable ram_file_line_v 	: line;
    variable ram_val_v        : std_logic_vector(RAM_W - 1 downto 0);
    variable ram_v            : asram_t;
    variable status_v         : boolean;
    
  begin

    -- open file
    file_open(ram_file_f,file_name,READ_MODE);

    for I in asram_t'range loop

      -- check EOF
      if(endfile(ram_file_f)) then       
        assert false
        report "End of File encountered... breaking." severity failure;
        exit;
      end if;

      -- read line
      readline(ram_file_f,ram_file_line_v);   
      read(ram_file_line_v,ram_val_v);
--      read(ram_file_line_v, ram_val_v, status_v);
--           assert status_v
--            report "File content error... breaking." severity failure;

      -- update ram content
      ram_v(I) := ram_val_v;
    end loop;   

    -- close file     
    file_close(ram_file_f);  
    
    return ram_v;                                                  
  end function init_from_file;
  
  -- //////////////////////////////////////////
  --                   RAM
  -- //////////////////////////////////////////

  signal asram_r : asram_t := init_from_file(MEM_FILE);

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal asram_we_s : std_ulogic;
  signal asram_re_s : std_ulogic;
  signal data_rd_s  : std_logic_vector(RAM_W - 1 downto 0);
  signal data_wr_s  : std_logic_vector(RAM_W - 1 downto 0) := asram_r(0); -- hack / avoid pb during init

begin
  
  -- //////////////////////////////////////////
  --               ASRAM BEHAVIOUR
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNAL
  --

  data_io    <= data_rd_s; 

  --
  -- ASSIGN INTERNAL SIGNALS
  --

  asram_we_s <= '1' when (ce_n_i = '0' and we_n_i = '0' and oe_n_i = '1') else '0';
  asram_re_s <= '1' when (ce_n_i = '0' and we_n_i = '1' and oe_n_i = '0') else '0';
  data_wr_s  <= data_io after 1 ns;

  --
  -- READ PROCESS
  --
  --! This process simulates the behaviour of
  --! a read operation of an asynchronous SRAM.
  BEHAVIOUR_READ_ASRAM: process(a_i,
                                asram_re_s)
  begin

    if(asram_re_s = '1') then
      for i in 0 to (RAM_W/8 - 1) loop
        if(sel_n_i(i) = '0') then
          data_rd_s(8*(i+1) - 1 downto 8*i) <= asram_r(to_integer(unsigned(a_i)))(8*(i+1) - 1 downto 8*i);

        else
          data_rd_s(8*(i+1) - 1 downto 8*i) <= (others => 'Z'); -- high impedance state

        end if;
      end loop;

    else
      data_rd_s <= (others => 'Z'); -- high impedance state

    end if;

  end process BEHAVIOUR_READ_ASRAM;

  --
  -- WRITE PROCESS
  --
  --! This process simulates the behaviour of
  --! a write operation of an asynchronous SRAM.
  BEHAVIOUR_WRITE_ASRAM: process(asram_we_s)
  begin

    if(asram_we_s'event and asram_we_s = '0') then
      for i in 0 to (RAM_W/8 - 1) loop
        if(sel_n_i(i) = '0') then
          asram_r(to_integer(unsigned(a_i)))(8*(i+1) - 1 downto 8*i) <= data_wr_s(8*(i+1) - 1 downto 8*i);
        end if;
      end loop;
    end if;

  end process BEHAVIOUR_WRITE_ASRAM;

end be_async_sram;   
   
