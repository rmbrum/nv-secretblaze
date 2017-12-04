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
--! @file sb_add.vhd                                      					
--! @brief SecretBlaze Adder Unit
--! @author Lyonel Barthe
--! @version 1.1
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.1 04/01/2011 by Lyonel Barthe
-- Removed Verilog implementation 
-- XST is still not able to correctly find
-- a n-bit adder with carry out using the
-- numeric_std VHDL package
-- FIX ME when VHDL 2008 will be supported
-- (cout_s, res_s) <= ('0' & a) + ('0' & b) + cin;
--
-- Version 1.0 02/2010 by Lyonel Barthe
-- Initial Release 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

--
--! This module implements the carry in/out main adder of the SecretBlaze.
--

--! SecretBlaze Adder Entity
entity sb_add is

  port
    (
      op_a_i    : in data_t;     --! first operand input
      op_b_i    : in data_t;     --! second operand input
      cin_i     : in std_ulogic; --! carry in 
      res_o     : out data_t;    --! adder result output
      cout_o    : out std_ulogic --! carry out 
    );  
  
end sb_add;

--! SecretBlaze Adder Architecture
architecture be_sb_add of sb_add is
  
  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
 
  signal res_s  : data_t;    
  signal cout_s : std_ulogic;
   
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --
  
  res_o  <= res_s;
  cout_o <= cout_s;

  --
  -- CARRY IN/OUT ADDER 
  --
  --! This process implements the adder of the processor.
  COMB_ADDER: process(op_a_i,
                      op_b_i,
                      cin_i)
							 
    variable cin_v       : std_ulogic_vector(0 downto 0);
    variable adder_res_v : std_ulogic_vector(data_t'length downto 0);
  
  begin

    -- use a 32-bit adder with carry in/out
    cin_v(0)    := cin_i;
    adder_res_v := std_ulogic_vector(unsigned('0' & op_a_i) + unsigned('0' & op_b_i) + unsigned(cin_v));   

    res_s       <= adder_res_v(data_t'length - 1 downto 0);
    cout_s      <= adder_res_v(data_t'length);

  end process COMB_ADDER;
           
end be_sb_add;

