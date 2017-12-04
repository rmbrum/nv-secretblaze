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
--! @file sb_btc.vhd                                      					
--! @brief SecretBlaze Branch Target Cache
--! @author Lyonel Barthe
--! @version 1.0
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 11/05/2011 by Lyonel Barthe
-- Initial Release 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

library config_lib;
use config_lib.sb_config.all;

library tool_lib;

--
--! The Branch Target Cache (BTC) contains the predicted addresses of 
--! branch instructions to improve the performance of the SecretBlaze 
--! processor. It is a configurable direct-mapped cache with one-cycle 
--! hit latency that operates in parallel to the fetch stage. 
--! 
--! Each cache entry consists of a tag field, a predicted address field, 
--! and a 2-bit prediction field.
--

--! SecretBlaze BTC Entity
entity sb_btc is

  generic 
    (
      BTC_MEM_TYPE  : string := USER_BTC_MEM_TYPE; --! BTC memory implementation type
      BTC_MEM_FILE  : string := USER_BTC_MEM_FILE; --! BTC memory init file 
      BTC_TAG_FILE  : string := USER_BTC_TAG_FILE  --! BTC tag memory init file 
    );

  port
    (
      btc_i         : in btc_i_t;                  --! BTC inputs
      btc_o         : out btc_o_t;                 --! BTC outputs
      halt_core_i   : in std_ulogic;               --! halt core signal 
      clk_i         : in std_ulogic                --! core clock
    );  
  
end sb_btc;

--! SecretBlaze BTC Architecture
architecture be_sb_btc of sb_btc is

  -- //////////////////////////////////////////
  --               INTERNAL REG
  -- ////////////////////////////////////////// 

  signal btc_tag_r            : btc_tag_t; --! BTC tag register

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  signal btc_tag_status_s     : btc_tag_status_t;

  --
  -- MEMORY SIGNALS
  --

  signal btc_ram_ena_s        : std_ulogic;
  signal btc_ram_we_s         : std_ulogic;
  signal btc_ram_adr_wr_s     : btc_index_adr_t;
  signal btc_ram_adr_rd_s     : btc_index_adr_t;
  signal btc_tag_ram_dat_i_s  : btc_tag_ram_data_t;
  signal btc_tag_ram_dat_o_s  : btc_tag_ram_data_t;
  signal btc_data_ram_dat_i_s : btc_pc_t;
  signal btc_data_ram_dat_o_s : btc_pc_t;

begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  TAG_RAM: entity tool_lib.dpram(be_dpram)
    generic map
    (
      RAM_TYPE => BTC_MEM_TYPE,
      MEM_FILE => BTC_TAG_FILE,
      RAM_W    => BTC_TAG_RAM_W,
      RAM_S    => BTC_S
    )
    port map
    (
      ena_i    => btc_ram_ena_s,           
      we_i     => btc_ram_we_s,   
      adr_1_i  => btc_ram_adr_wr_s,
      adr_2_i  => btc_ram_adr_rd_s,
      dat_i    => btc_tag_ram_dat_i_s,
      dat_1_o  => open,
      dat_2_o  => btc_tag_ram_dat_o_s,
      clk_i    => clk_i
    );

  BTC_MEM: entity tool_lib.dpram(be_dpram)
    generic map
    (
      RAM_TYPE => BTC_MEM_TYPE,
      MEM_FILE => BTC_MEM_FILE,
      RAM_W    => BTC_PC_W,
      RAM_S    => BTC_S
    )
    port map
    (
      ena_i    => btc_ram_ena_s,           
      we_i     => btc_ram_we_s,   
      adr_1_i  => btc_ram_adr_wr_s,
      adr_2_i  => btc_ram_adr_rd_s,
      dat_i    => btc_data_ram_dat_i_s,
      dat_1_o  => open,
      dat_2_o  => btc_data_ram_dat_o_s,
      clk_i    => clk_i
    );

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --

  -- registered signals
  btc_o.pred_pc_o      <= (btc_data_ram_dat_o_s & WORD_0_PADDING);
  btc_o.pred_status_o  <= btc_tag_ram_dat_o_s(BTC_STATUS_HIGH_OFF downto BTC_STATUS_BASE_OFF);
  -- combinatorial signal
  btc_o.tag_status_o   <= btc_tag_status_s;

  --
  -- ASSIGN INTERNAL SIGNALS
  --

  btc_ram_ena_s        <= not(halt_core_i);
  btc_ram_adr_rd_s     <= btc_i.fetch_adr_i(BTC_W + WORD_ADR_OFF - 1 downto WORD_ADR_OFF);
  btc_ram_we_s         <= btc_i.we_i;
  btc_ram_adr_wr_s     <= btc_i.new_inst_pc_i(BTC_W + WORD_ADR_OFF - 1 downto WORD_ADR_OFF);
  btc_data_ram_dat_i_s <= btc_i.new_pred_pc_i(PC_W - 1 downto WORD_ADR_OFF);
  btc_tag_ram_dat_i_s  <= (btc_i.new_pred_status_i & btc_i.new_inst_pc_i(PC_W - 1 downto PC_W - BTC_TAG_W));

  --
  -- TAG COMP
  --
  --! This process implements the cache hit signal. If the tag from the cpu 
  --! address is equal to the tag stored into the tag memory, then the data 
  --! is available from the branch target memory (cache-hit). 
  COMB_BTC_TAG_STATUS: process(btc_tag_r,
                               btc_tag_ram_dat_o_s)

    alias btc_tag_a is btc_tag_ram_dat_o_s(btc_tag_t'length - 1 downto 0);

  begin
    
    -- cache-hit
    if(btc_tag_a = btc_tag_r) then
      btc_tag_status_s <= BTC_HIT;

      -- cache-miss
    else
      btc_tag_status_s <= BTC_MISS;

    end if;  
    
  end process COMB_BTC_TAG_STATUS;  

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- BTC TAG REGISTER
  --
  --! This process implements the tag register.
  CYCLE_BTC_TAG: process(clk_i)		
  begin
      
    -- clock event
    if(clk_i'event and clk_i = '1') then

      if(halt_core_i = '0') then
         btc_tag_r <= btc_i.fetch_adr_i(PC_W - 1 downto PC_W - BTC_TAG_W);
      end if;
      
    end if;
    
  end process CYCLE_BTC_TAG;    

end be_sb_btc;

