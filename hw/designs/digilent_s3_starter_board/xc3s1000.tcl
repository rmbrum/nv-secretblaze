##
##    ADAC Research Group - LIRMM - University of Montpellier / CNRS 
##    contact: adac@lirmm.fr
##
##    This file is part of SecretBlaze.
##
##    SecretBlaze is free software: you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation, either version 3 of the License, or
##    (at your option) any later version.
##
##    SecretBlaze is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with SecretBlaze.  If not, see <http://www.gnu.org/licenses/>.
##

#############################################################
#-----------------------------------------------------------#
#                                                           #  
# Company       : LIRMM                                     #
# Engineer      : Lyonel Barthe                             #
# Version       : 1.6                                       #
#                                                           #
# Revision History :                                        #
#                                                           #
#   Version 1.6 - 08/2012 by Lyonel Barthe                  #
#       Fixed a bug with fuse                               #
#                                                           #
#   Version 1.5 - 26/05/2011 by Lyonel Barthe               #
#       Cleaned the code                                    #
#                                                           #
#   Version 1.4 - 23/04/2010 by Lyonel Barthe               #
#       Work with absolute path                             #
#                                                           #
#   Version 1.3 - 23/04/2010 by Lyonel Barthe               #
#       Fixed some exception bugs                           #
#                                                           #
#   Version 1.2 - 15/04/2010 by Lyonel Barthe               #
#       Fix a bug with the sim command                      #
#                                                           #
#   Version 1.1 - 11/02/2010 by Lyonel Barthe               #
#       ISIM support                                        #
#                                                           #
#   Version 1.0 - 10/02/2010 by Lyonel Barthe               #
#       Initial Release                                     #
#                                                           #
#-----------------------------------------------------------#
#############################################################

#############################################################
#-----------------------------------------------------------#
#                                                           #
#                    GETTING STARTED                        #
#                                                           #
#                                                           #
# xtclsh <filename>.tcl <options>                           #
# or                                                        #
# source <filename>.tcl inside a xtclsh terminal            #
#                                                           #
#-----------------------------------------------------------#
#############################################################

#############################################################
#-----------------------------------------------------------#
#                                                           #
#                     SCRIPT SETTINGS                       #
#                                                           #
#-----------------------------------------------------------#
#############################################################
		
#                                                           #
#-----------------------------------------------------------#	

#-----------------------------------------------------------#
#                                                           #
#                     RECURSIVE FIND                        #
#                                                           #

proc rfile {dir file} {
  if {[llength [set path [glob -nocomplain -dir $dir $file]]]} {
    return [lindex $path 0]
  } else {
    foreach i [glob -nocomplain -type d -dir $dir *] {
      if {$i != $dir && [llength [set path [rfile $i $file]]]} {
        return $path
      }	 
    }	
  }
}
		
#                                                           #
#-----------------------------------------------------------#

#-----------------------------------------------------------#
#                                                           #
#                     PROJECT SETTINGS                      #
#                                                           #
#                                                           #

set project_name        secretblaze
set myScript            xc3s1000.tcl
set version             1.6

set top_path            [file dirname [rfile [pwd] $myScript]]

set working_dir         $top_path/../../proj
set bit_dir             $top_path
set ucf_dir             $top_path
set src_dir             $top_path/../../rtl
set tb_dir              $top_path/tb

set xst_working_dir     xst 
set impact_file         iMPACT_config.ipf
set isim_proj           $project_name.prj
set fuse_file           fuse_settings.txt
set sim_tcl_file        simu_settings.tcl

set myProject           $working_dir/$project_name

#                                                           #
#-----------------------------------------------------------#			

#-----------------------------------------------------------#
#                                                           #
#                         FILES                             #
#                                                           #
#

#
# HARDWARE FILES
#

set top_hw $top_path/xc3s1000_top.vhd  

set tool_lib_files [ list                                       \
          $src_dir/tool_lib/ram/dpram.vhd                       \
          $src_dir/tool_lib/ram/dpram4x8.vhd                    \
          $src_dir/tool_lib/math_pack.vhd                       \
          $src_dir/tool_lib/debounce_unit.vhd                   \
  ]

set wb_lib_files [ list                                         \
          $src_dir/wb_lib/wb_arb.vhd                            \
          $src_dir/wb_lib/wb_top.vhd                            \
          $src_dir/wb_lib/wb_pack.vhd                           \
  ]

set sb_lib_files [ list                                         \
          $src_dir/sb_lib/core/sb_execute.vhd                   \
          $src_dir/sb_lib/core/sb_memory_access.vhd             \
          $src_dir/sb_lib/core/sb_write_back.vhd                \
          $src_dir/sb_lib/core/sb_core.vhd                      \
          $src_dir/sb_lib/core/sb_fetch.vhd                     \
          $src_dir/sb_lib/core/sb_decode.vhd                    \
          $src_dir/sb_lib/core/sb_rf.vhd                        \
          $src_dir/sb_lib/core/sb_beval.vhd                     \
          $src_dir/sb_lib/core/sb_branch_controller.vhd         \
          $src_dir/sb_lib/core/sb_btc.vhd                       \
          $src_dir/sb_lib/core/sb_add.vhd                       \
          $src_dir/sb_lib/core/sb_cmp.vhd                       \
          $src_dir/sb_lib/core/sb_bs.vhd                        \
          $src_dir/sb_lib/core/sb_pipe_bs_1.vhd                 \
          $src_dir/sb_lib/core/sb_pipe_bs_2.vhd                 \
          $src_dir/sb_lib/core/sb_mult.vhd                      \
          $src_dir/sb_lib/core/sb_pipe_mult_1.vhd               \
          $src_dir/sb_lib/core/sb_pipe_mult_2.vhd               \
          $src_dir/sb_lib/core/sb_div.vhd                       \
          $src_dir/sb_lib/core/sb_pat.vhd                       \
          $src_dir/sb_lib/core/sb_clz.vhd                       \
          $src_dir/sb_lib/core/sb_pipe_clz_1.vhd                \
          $src_dir/sb_lib/core/sb_pipe_clz_2.vhd                \
          $src_dir/sb_lib/core/sb_core_pack.vhd                 \
          $src_dir/sb_lib/core/sb_isa.vhd                       \
          $src_dir/sb_lib/core/sb_hazard_controller.vhd         \
          $src_dir/sb_lib/memory/sb_memory_unit_pack.vhd        \
          $src_dir/sb_lib/memory/sb_icache.vhd                  \
          $src_dir/sb_lib/memory/sb_dcache.vhd                  \
          $src_dir/sb_lib/memory/sb_lmemory.vhd                 \
          $src_dir/sb_lib/memory/sb_idecoder.vhd                \
          $src_dir/sb_lib/memory/sb_ddecoder.vhd                \
          $src_dir/sb_lib/memory/sb_iwb_interface.vhd           \
          $src_dir/sb_lib/memory/sb_dwb_interface.vhd           \
          $src_dir/sb_lib/memory/sb_memory_unit_controller.vhd  \
          $src_dir/sb_lib/memory/sb_imemory_unit.vhd            \
          $src_dir/sb_lib/memory/sb_dmemory_unit.vhd            \
          $src_dir/sb_lib/memory/sb_memory_unit.vhd             \
          $src_dir/sb_lib/sb_cpu.vhd                            \
  ]

set soc_lib_files [ list                                        \
          $src_dir/soc_lib/uart/uart_top.vhd                    \
          $src_dir/soc_lib/uart/uart_slave_wb_bus.vhd           \
          $src_dir/soc_lib/uart/uart_pack.vhd                   \
          $src_dir/soc_lib/uart/uart_controller.vhd             \
          $src_dir/soc_lib/gpio/gpio_slave_wb_bus.vhd           \
          $src_dir/soc_lib/gpio/gpio_pack.vhd                   \
          $src_dir/soc_lib/intc/intc_slave_wb_bus.vhd           \
          $src_dir/soc_lib/intc/intc_pack.vhd                   \
          $src_dir/soc_lib/timer/timer_slave_wb_bus.vhd         \
          $src_dir/soc_lib/timer/timer_pack.vhd                 \
          $src_dir/soc_lib/sram/sram_top.vhd                    \
          $src_dir/soc_lib/sram/sram_slave_wb_bus.vhd           \
          $src_dir/soc_lib/sram/sram_controller.vhd             \
          $src_dir/soc_lib/sram/sram_pack.vhd                   \
          $top_path/soc.vhd                                     \
  ]

set config_lib_files [ list                                     \
          $top_path/config_lib/soc_config.vhd                   \
          $top_path/config_lib/sb_config.vhd                    \
          $top_path/config_lib/sim_config.vhd                   \
  ]  

#
# SIMULATION FILES
#

set tb_files [ list                                             \
          $tb_dir/tb_lib/async_sram.vhd                         \
  ]

set test_bench_name     tb_soc				
set top_tb              $tb_dir/$test_bench_name.vhd     
set wcfg_file           $tb_dir/tb_soc.wcfg          	

#
# BOARD FILES
#

set fpga_family         "Spartan3"					
set fpga_device         "xc3s1000"						
set fpga_pack           "ft256"					
set fpga_speed          "-4"						

set constraint_file     $ucf_dir/xc3s1000.ucf			
set top_level_inst      be_xc3s1000_top
set top_level_entity    xc3s1000_top
	
#                                                           #
#-----------------------------------------------------------#

#############################################################
#-----------------------------------------------------------#
#                                                           #
#                      IMPLEMENTATION                       #
#                                                           #
#-----------------------------------------------------------#
#############################################################

# 
# show_help
#           
proc show_help {} {

  global myScript
  global version

  set systime [clock seconds]

  puts " -------------------------------------------------------------- "
  puts "   XST script by Lyonel Barthe <lyonel.barthe@lirmm.fr>"
  puts "   Version $version"
  puts ""
  puts "   Have fun! :-)"
  puts ""
  puts "   [clock format $systime]"
  puts " -------------------------------------------------------------- "
  puts ""
  puts "usage: xtclsh $myScript <options>"
  puts "       or you can run xtclsh and then enter 'source $myScript'."
  puts ""
  puts "options:"
  puts "   show_help         - print this message"
  puts "   clean             - clean project" 
  puts "   make              - make new project"
  puts "   all               - rebuild_all + down processes"
  puts "   rebuild_all       - rebuild the project from scratch and run processes"
  puts "   check             - check syntax"
  puts "   rs                - run synthesize"
  puts "   rp                - run par"
  puts "   rb                - run programming file generation"
  puts "   down              - download the bitstream directly via impact"
  puts "   add               - add source files"
  puts "   sim               - launch the simulation"
  puts "   isim              - launch ISIM"
  puts ""
  
  return true
}

#
# make project
#
proc make {} {
    
  # global vars
  global myScript
  global myProject
  global top_path

  puts "" 
  puts " -------------------------------------------------------------"
  puts "                     Making new project...                    "
  puts " -------------------------------------------------------------"
  puts ""
  
  puts "  $myScript: making ($myProject)..."

  # create a new project
  if { [catch {project new $myProject} msg]} {
    puts "  $myScript: Can't create project..."
    puts $msg
        
    return false
  }
  
  # for display
  puts ""
  
  # add project settings
  set_project_props

  # keep hierarchy
  cd $top_path

  project close
  
  return true
}

#
# clean
#
proc clean {} {

  # global vars
  global myScript
  global myProject 
  global working_dir
  
  puts ""  
  puts " -------------------------------------------------------------"
  puts "                          Cleaning...                         "
  puts " -------------------------------------------------------------"
  puts ""
  
  puts "  $myScript: cleaning ($myProject)..."
  puts ""
  
  # clean all files
  set all_files [glob -directory $working_dir -nocomplain *]
  foreach i $all_files {
      file delete -force $i
  }

  puts "  $myScript: cleaning completed."
  puts ""

  return true
}

#
# file error management
#
proc file_exist {name} {

  # global vars
  global myScript
  global top_path
  
  if { ! [file exists $name ] } {
    puts "  $myScript: failed to find $name."

    # keep hierarchy
    cd $top_path

    project close

    return false
  }
  
  return true
}

#
# add
#
proc add {} {

  # global vars
  global myProject
  global myScript
  global sb_lib_files
  global wb_lib_files
  global soc_lib_files
  global config_lib_files
  global tool_lib_files
  global tb_files
  global top_hw
  global constraint_file 
  global top_level_inst
  global top_level_entity
  global top_path

  puts ""
  puts " -------------------------------------------------------------"
  puts "                     Adding source files...                   "
  puts " -------------------------------------------------------------"
  puts ""
  
  # open project
  if { ! [ open_project ] } {
    puts "  $myScript: failed to open ($myProject)."
    puts ""

    return false
  }
  
  # for display
  puts ""
  
  puts "  $myScript: adding sources to project..."

  lib_vhdl new tool_lib

  foreach filename $tool_lib_files {
    if { ! [file_exist $filename] } {
      return false
    }

    xfile add $filename -lib_vhdl tool_lib 
    puts "      adding file $filename to the project."

  }

  lib_vhdl new wb_lib

  foreach filename $wb_lib_files {
    if { ! [file_exist $filename] } {
      return false
    }

    xfile add $filename -lib_vhdl wb_lib 
    puts "      adding file $filename to the project."

  }

  lib_vhdl new sb_lib

  foreach filename $sb_lib_files {
    if { ! [file_exist $filename] } {
      return false
    }

    xfile add $filename -lib_vhdl sb_lib 
    puts "      adding file $filename to the project."

  }

  lib_vhdl new soc_lib

  foreach filename $soc_lib_files {
    if { ! [file_exist $filename] } {
      return false
    }

    xfile add $filename -lib_vhdl soc_lib 
    puts "      adding file $filename to the project."

  }

  lib_vhdl new config_lib

  foreach filename $config_lib_files {
    if { ! [file_exist $filename] } {
      return false
    }

    xfile add $filename -lib_vhdl config_lib 
    puts "      adding file $filename to the project."

  }

  # top hw file
  if { ! [file_exist $top_hw] } {
      return false
  }
  xfile add $top_hw  
  puts "      adding file $top_hw to the project."

  # for display
  puts ""

  # set UCF
  puts "  $myScript: adding ucf file to project..."
  if { ! [file_exist $constraint_file] } {
    return false
  }   
  xfile add $constraint_file 
  puts "      adding file $constraint_file to the project."
  
  # for display
  puts ""
  
  # Set top module
  puts "  $myScript: setting top level module to project..."
  project set top $top_level_inst $top_level_entity
  puts "      setting $top_level_entity as top module."
  
  # for display
  puts ""
  
  puts "  $myScript: project sources reloaded."
  puts ""

  # keep hierarchy
  cd $top_path

  project close
  
  return true
}

# 
# rs
# 
proc rs {} {

  # global vars
  global myScript
  global myProject
  global top_path

  puts ""
  puts " -------------------------------------------------------------"
  puts "                      Running Synthesize...                   "
  puts " -------------------------------------------------------------"
  puts ""
  
  puts "  $myScript: running ($myProject)..."
  
  # open project
  if { ! [ open_project ] } {
    puts "  $myScript: failed to open ($myProject)."
    puts ""
	
    return false
  }
  
  # for display
  puts ""

  # settings
  set_process_props_synth

  # time benchmark
  set tic [clock seconds]

  # run synthesize process
  if { [catch {process run "Synthesize" -force rerun} msg]} {
    puts "  $myScript: synthesize run failed, check run output for details."
    puts $msg

    # keep hierarchy
    cd $top_path/

    project close

    return false
  }

  # time benchmark
  set toc [clock seconds]
  set res [expr $toc - $tic]
  
  puts ""
  puts "  $myScript: synthesize done in $res seconds!"
    
  puts ""
  puts " -------------------------------------------------------------"
  puts "                         Completed!!!!                        "
  puts " -------------------------------------------------------------"
  puts ""
  
  # keep hierarchy
  cd $top_path/
	
  project close
  
  return true
}

# 
# rp
# 
proc rp {} {

  # global vars
  global myScript
  global myProject
  global top_path

  puts ""
  puts " -------------------------------------------------------------"
  puts "                      Running PAR...                          "
  puts " -------------------------------------------------------------"
  puts ""
  
  puts "  $myScript: running ($myProject)..."

  # open project
  if { ! [ open_project ] } {
    puts "  $myScript: failed to open ($myProject)."
    puts ""

    return false
  }
  
  # for display
  puts ""
  
  # settings
  set_process_props_par

  # time benchmark
  set tic [clock seconds]
  
  # run P&R process 
  if {[catch {process run "Place & Route" -force rerun} msg] } {
    puts "  $myScript: place & route run failed, check run output for details."
    puts $msg        

    # keep hierarchy
    cd $top_path/
	
    project close

    return false
  }

  # time benchmark
  set toc [clock seconds]
  set res [expr $toc - $tic]
  
  puts ""
  puts "  $myScript: par done in $res seconds!"

  puts ""
  puts " -------------------------------------------------------------"
  puts "                         Completed!!!!                        "
  puts " -------------------------------------------------------------"
  puts ""

  # keep hierarchy
  cd $top_path/
	
  project close
  
  return true
}

#
# rb
#
proc rb {} {

  # global vars
  global myScript
  global myProject
  global bit_dir
  global top_path

  puts ""
  puts " -------------------------------------------------------------"
  puts "                      Generate Bitstream...                   "
  puts " -------------------------------------------------------------"
  puts ""
  
  puts "  $myScript: running ($myProject)...\n"
  
  # open project
  if { ! [ open_project ] } {
    puts "  $myScript: failed to open ($myProject)."
    puts ""

    return false
  }
  
  # for display
  puts ""
  
  # settings
  set_process_props_bit

  # time benchmark
  set tic [clock seconds]

  # run bitstream gen process
  if {[catch {process run "Generate Programming File" -force rerun} msg] } {
    puts "  $myScript: generate programming file run failed, check run output for details."
    puts $msg        

    # keep hierarchy
    cd $top_path/
	
    project close

    return false
  }

  # time benchmark
  set toc [clock seconds]
  set res [expr $toc - $tic]
  
  puts ""
  puts "  $myScript: gen bitstream done in $res seconds!"

  # copy bit file
  set bit_files [glob -nocomplain *.bit]
  foreach i $bit_files {
      file delete -force $bit_dir/$i
  }
  foreach i $bit_files {
      file copy $i $bit_dir
  }

  puts ""
  puts " -------------------------------------------------------------"
  puts "                         Completed!!!!                        "
  puts " -------------------------------------------------------------"
  puts ""

  # keep hierarchy
  cd $top_path/
	
  project close
  
  return true
}

# 
# check
# 
proc check {} {

  # global vars
  global myScript
  global myProject
  global top_path

  puts ""
  puts " -------------------------------------------------------------"
  puts "                      Checking syntax...                      "
  puts " -------------------------------------------------------------"
  puts ""

  puts "  $myScript: running ($myProject)..."

  # open project
  if { ! [ open_project ] } {
    puts "  $myScript: failed to open ($myProject)."
    puts ""

    return false
  }
  
  # for display
  puts ""

  # check syntax
  if {[catch {process run "Check Syntax" -force rerun} msg]} {
    puts "  $myScript: check Syntax run failed, check run output for details."
    puts $msg      

    # keep hierarchy
    cd $top_path/

    project close

    return false
  }
  
  puts ""
  puts " -------------------------------------------------------------"
  puts "                         Completed!!!!                        "
  puts " -------------------------------------------------------------"
  puts ""
  
  # keep hierarchy
  cd $top_path/
	
  project close
  
  return true
}

#
# down
#
proc down {} {

  # global vars
  global myScript
  global myProject
  global top_level_entity
  global bit_dir
  global impact_file 
  global working_dir
  global top_path

  puts ""
  puts " -------------------------------------------------------------"
  puts "                       Starting iMPACT...                     "
  puts " -------------------------------------------------------------"
  puts ""
  
  puts "  $myScript: running ($myProject)...\n"
  puts ""
  
  # change path
  cd $working_dir

  # create a new impact file
  if {[catch {set f_id [open $impact_file w]} msg]} {  
    puts "  $myScript: can't create $impact_file"
    puts $msg
    puts ""

    # keep hierarchy
    cd $top_path/

    return false
  }

  # set auto config
  set bit_path_name $bit_dir/$top_level_entity.bit
  puts $f_id "setMode -bscan"
  puts $f_id "setCable -port auto"
  puts $f_id "identify"
  puts $f_id "assignFile -p 1 -file $bit_path_name"
  puts $f_id "program -p 1"
  puts $f_id "quit"
  close $f_id

  # run impact
  if {[catch { 

    set impact_p [open "|impact -batch $impact_file" r]
    while {![eof $impact_p]} { 
        gets $impact_p line  
        puts $line 
    }

  } msg]} {
    puts "  $myScript: can't run impact..."
    puts $msg
    puts ""

    # keep hierarchy
    cd $top_path/

    return false	
  }   

  # clean exit
  if {[catch { close $impact_p} msg]} {
    puts $msg
  }

  # keep hierarchy
  cd $top_path/

  return true
}

#
# rebuild_all
#
proc rebuild_all {} {

  # global vars
  global myScript 
  global myProject
  global bit_dir
  global top_path
  
  # clean
  if { ! [clean] } {
    return false
  }
  
  # make
  if { ! [make] } {
    return false
  }

  puts ""
  puts " -------------------------------------------------------------"
  puts "                        Rebuilding...                         "
  puts " -------------------------------------------------------------"
  puts ""
  puts "  $myScript: rebuilding ($myProject)..."

  # add source files
  if { ! [add] } {
    return false
  }

  # open project
  if { ! [ open_project ] } {
    puts "  $myScript: failed to open ($myProject)."
    puts ""

    return false
  }

  # for display
  puts ""
  
  # settings
  set_process_props_synth
  set_process_props_par
  set_process_props_bit

  # run synthesize process
  if { [catch {process run "Synthesize"} msg]} {
    puts "  $myScript: synthesize run failed, check run output for details."
    puts $msg

    # keep hierarchy
    cd $top_path/

    project close

    return false
  }
  
  # run P&R process 
  if {[catch {process run "Place & Route"} msg] } {
    puts "  $myScript: place & route run failed, check run output for details."
    puts $msg
	
    # keep hierarchy
    cd $top_path/
	
    project close

    return false
  }

  # run bitstream gen process
  if {[catch {process run "Generate Programming File"} msg] } {
    puts "  $myScript: generate programming file run failed, check run output for details."
    puts $msg

    # keep hierarchy
    cd $top_path/

    project close

    return false
  }
  
  # copy bit file
  set bit_files [glob -nocomplain *.bit]
  foreach i $bit_files {
      file delete $bit_dir/$i
  }
  foreach i $bit_files {
      file copy $i $bit_dir
  }
  
  puts ""
  puts " -------------------------------------------------------------"
  puts "                         Completed!!!!                        "
  puts " -------------------------------------------------------------"
  puts ""

  # keep hierarchy
  cd $top_path/

  project close
  
  return true
}

#
# all
#
proc all {} {

  # make all 
  if { ! [rebuild_all] } {
    return false
  }

  # download bitstream
  if { ! [down] } {
    return false
  }
  
  return true
}

#
# open_project
#
proc open_project {} {

  # global vars
  global myScript
  global myProject

  if { ! [ file exists ${myProject}.xise ] } { 
    puts "Project $myProject not found. Use make to recreate it.\n"
    return false
  }

  project open $myProject

  return true
}

# 
# set_project_props
# 
proc set_project_props {} {

  # global vars
  global myScript
  global fpga_family 
  global fpga_device 
  global fpga_pack   
  global fpga_speed  

  puts "  $myScript: Setting project properties..."

  # fpga settings
  project set family  $fpga_family 
  project set device  $fpga_device 
  project set package $fpga_pack
  project set speed   $fpga_speed 
  puts "      FPGA configuration: $fpga_family | $fpga_device | $fpga_pack | $fpga_speed"
  puts ""

  # other settings
  project set top_level_module_type "HDL"
  project set synthesis_tool "XST (VHDL/Verilog)"
  project set simulator "ISim (VHDL/Verilog)"
  project set "Preferred Language" "VHDL"
  project set "Enable Message Filtering" "false"
  project set "Display Incremental Messages" "false"
  puts ""

}

#
# set_process_props_synth
#
proc set_process_props_synth {} {

  global myScript
  global xst_working_dir

  puts "   $myScript: setting process synth properties..."

  project set "Work Directory" "$xst_working_dir" -process "Synthesize - XST"

  project set "Multiplier Style" "Auto" -process "Synthesize - XST"
  project set "Number of Clock Buffers" "8" -process "Synthesize - XST"
  project set "Max Fanout" "500" -process "Synthesize - XST"
  project set "Case Implementation Style" "None" -process "Synthesize - XST"
  project set "Decoder Extraction" "true" -process "Synthesize - XST"
  project set "Priority Encoder Extraction" "Yes" -process "Synthesize - XST"
  project set "Mux Extraction" "Yes" -process "Synthesize - XST"
  project set "RAM Extraction" "true" -process "Synthesize - XST"
  project set "ROM Extraction" "true" -process "Synthesize - XST"
  project set "FSM Encoding Algorithm" "Auto" -process "Synthesize - XST"
  project set "Logical Shifter Extraction" "true" -process "Synthesize - XST"
  project set "Optimization Goal" "Speed" -process "Synthesize - XST"
  project set "Optimization Effort" "Normal" -process "Synthesize - XST"
  project set "Resource Sharing" "true" -process "Synthesize - XST"
  project set "Shift Register Extraction" "true" -process "Synthesize - XST"
  project set "XOR Collapsing" "true" -process "Synthesize - XST"
  project set "Add I/O Buffers" "true" -process "Synthesize - XST"
  project set "Global Optimization Goal" "AllClockNets" -process "Synthesize - XST"
  project set "Keep Hierarchy" "No" -process "Synthesize - XST"
  project set "Register Balancing" "No" -process "Synthesize - XST"
  project set "Register Duplication" "true" -process "Synthesize - XST"
  project set "Asynchronous To Synchronous" "false" -process "Synthesize - XST"
  project set "Automatic BRAM Packing" "false" -process "Synthesize - XST"
  project set "BRAM Utilization Ratio" "100" -process "Synthesize - XST"
  project set "Bus Delimiter" "<>" -process "Synthesize - XST"
  project set "Case" "Maintain" -process "Synthesize - XST"
  project set "Cores Search Directories" "" -process "Synthesize - XST"
  project set "Cross Clock Analysis" "true" -process "Synthesize - XST"
  project set "Equivalent Register Removal" "true" -process "Synthesize - XST"
  project set "FSM Style" "LUT" -process "Synthesize - XST"
  project set "Generate RTL Schematic" "Yes" -process "Synthesize - XST"
  project set "Generics, Parameters" "" -process "Synthesize - XST"
  project set "Hierarchy Separator" "/" -process "Synthesize - XST"
  project set "HDL INI File" "" -process "Synthesize - XST"
  project set "Library Search Order" "" -process "Synthesize - XST"
  project set "Netlist Hierarchy" "As Optimized" -process "Synthesize - XST"
  project set "Optimize Instantiated Primitives" "false" -process "Synthesize - XST"
  project set "Pack I/O Registers into IOBs" "Auto" -process "Synthesize - XST"
  project set "Read Cores" "true" -process "Synthesize - XST"
  project set "Slice Packing" "true" -process "Synthesize - XST"
  project set "Slice Utilization Ratio" "100" -process "Synthesize - XST"
  project set "Use Clock Enable" "Yes" -process "Synthesize - XST"
  project set "Use Synchronous Reset" "Yes" -process "Synthesize - XST"
  project set "Use Synchronous Set" "Yes" 
  project set "Use Synthesis Constraints File" "true" -process "Synthesize - XST"
  project set "Verilog Include Directories" "" -process "Synthesize - XST"
  project set "Verilog 2001" "true" -process "Synthesize - XST"
  project set "Verilog Macros" "" -process "Synthesize - XST"
  project set "Write Timing Constraints" "false" -process "Synthesize - XST"
  project set "Other XST Command Line Options" "" -process "Synthesize - XST"
  project set "Synthesis Constraints File" "" -process "Synthesize - XST"
  project set "Mux Style" "Auto" -process "Synthesize - XST"
  project set "RAM Style" "Auto" -process "Synthesize - XST"
  project set "Move First Flip-Flop Stage" "true" -process "Synthesize - XST"
  project set "Move Last Flip-Flop Stage" "true" -process "Synthesize - XST"
  project set "ROM Style" "Auto" -process "Synthesize - XST"
  project set "Safe Implementation" "No" -process "Synthesize - XST"

  puts "   $myScript: project property values set."
  puts ""

} 

#
# set_process_props_par
#
proc set_process_props_par {} {

  global myScript

  puts "   $myScript: setting process par properties..."

  project set "Use LOC Constraints" "true" -process "Translate"
  project set "Other Ngdbuild Command Line Options" "" -process "Translate"
  project set "Create I/O Pads from Ports" "false" -process "Translate"
  project set "Macro Search Path" "" -process "Translate"
  project set "Netlist Translation Type" "Timestamp" -process "Translate"
  project set "User Rules File for Netlister Launcher" "" -process "Translate"
  project set "Allow Unexpanded Blocks" "false" -process "Translate"
  project set "Allow Unmatched LOC Constraints" "false" -process "Translate"
  project set "Allow Unmatched Timing Group Constraints" "false" -process "Translate"

  project set "Timing Mode" "Non Timing Driven" -process "Map"
  project set "CLB Pack Factor Percentage" "100" -process "Map"
  project set "Ignore User Timing Constraints" "false" -process "Map"
  project set "Use RLOC Constraints" "Yes" -process "Map"
  project set "Other Map Command Line Options" "" -process "Map"
  project set "Allow Logic Optimization Across Hierarchy" "false" -process "Map"
  project set "Optimization Strategy (Cover Mode)" "Speed" -process "Map"
  project set "Pack I/O Registers/Latches into IOBs" "Off" -process "Map"
  project set "Generate Detailed MAP Report" "false" -process "Map"
  project set "Map Slice Logic into Unused Block RAMs" "false" -process "Map"
  project set "Perform Timing-Driven Packing and Placement" "false" -process "Map"
  project set "Trim Unconnected Signals" "true" -process "Map"
  project set "Map Effort Level" "Standard" -process "Map"
  project set "Combinatorial Logic Optimization" "false" -process "Map"
  project set "Starting Placer Cost Table (1-100)" "1" -process "Map"
  project set "Power Reduction" "false" -process "Map"
  project set "Register Duplication" "Off" -process "Map"
  project set "Extra Effort" "None" -process "Map"
  project set "Power Activity File" "" -process "Map"

  project set "Ignore User Timing Constraints" "false" -process "Place & Route"
  project set "Other Place & Route Command Line Options" "" -process "Place & Route"
  project set "Placer Effort Level (Overrides Overall Level)" "None" -process "Place & Route"
  project set "Router Effort Level (Overrides Overall Level)" "None" -process "Place & Route"
  project set "Place And Route Mode" "Normal Place and Route" -process "Place & Route"
  project set "Use Bonded I/Os" "false" -process "Place & Route"
  project set "Power Activity File" "" -process "Place & Route"
  project set "Extra Effort (Highest PAR level only)" "None" -process "Place & Route"
  project set "Starting Placer Cost Table (1-100)" "1" -process "Place & Route"
  project set "Generate Asynchronous Delay Report" "false" -process "Place & Route"
  project set "Generate Clock Region Report" "false" -process "Place & Route"
  project set "Generate Post-Place & Route Power Report" "false" -process "Place & Route"
  project set "Generate Post-Place & Route Simulation Model" "false" -process "Place & Route"
  project set "Power Reduction" "false" -process "Place & Route"
  project set "Timing Mode" "Performance Evaluation" -process "Place & Route"
  project set "Place & Route Effort Level (Overall)" "Standard" -process "Place & Route"

  puts "   $myScript: project property values set."
  puts ""

  puts "   $myScript: project property values set."
  puts ""

} 

#
# set_process_props_bit
#
proc set_process_props_bit {} {

  global myScript

  puts "   $myScript: setting process bit properties..."

  project set "DCI Update Mode" "As Required" -process "Generate Programming File"
  project set "Configuration Rate" "Default (6)" -process "Generate Programming File"
  project set "Configuration Clk (Configuration Pins)" "Pull Up" -process "Generate Programming File"
  project set "UserID Code (8 Digit Hexadecimal)" "0xFFFFFFFF" -process "Generate Programming File"
  project set "Reset DCM if SHUTDOWN & AGHIGH performed" "false" -process "Generate Programming File"
  project set "Configuration Pin Done" "Pull Up" -process "Generate Programming File"
  project set "Create ASCII Configuration File" "false" -process "Generate Programming File"
  project set "Create Bit File" "true" -process "Generate Programming File"
  project set "Enable BitStream Compression" "false" -process "Generate Programming File"
  project set "Run Design Rules Checker (DRC)" "true" -process "Generate Programming File"
  project set "Enable Cyclic Redundancy Checking (CRC)" "true" -process "Generate Programming File"
  project set "Create IEEE 1532 Configuration File" "false" -process "Generate Programming File"
  project set "Configuration Pin HSWAPEN" "Pull Up" -process "Generate Programming File"
  project set "Configuration Pin M0" "Pull Up" -process "Generate Programming File"
  project set "Configuration Pin M1" "Pull Up" -process "Generate Programming File"
  project set "Configuration Pin M2" "Pull Up" -process "Generate Programming File"
  project set "Configuration Pin Program" "Pull Up" -process "Generate Programming File"
  project set "JTAG Pin TCK" "Pull Up" -process "Generate Programming File"
  project set "JTAG Pin TDI" "Pull Up" -process "Generate Programming File"
  project set "JTAG Pin TDO" "Pull Up" -process "Generate Programming File"
  project set "JTAG Pin TMS" "Pull Up" -process "Generate Programming File"
  project set "Unused IOB Pins" "Pull Down" -process "Generate Programming File"
  project set "Security" "Enable Readback and Reconfiguration" -process "Generate Programming File"
  project set "FPGA Start-Up Clock" "CCLK" -process "Generate Programming File"
  project set "Done (Output Events)" "Default (4)" -process "Generate Programming File"
  project set "Drive Done Pin High" "false" -process "Generate Programming File"
  project set "Enable Outputs (Output Events)" "Default (5)" -process "Generate Programming File"
  project set "Wait for DCI Match (Output Events)" "Auto" -process "Generate Programming File"
  project set "Wait for DLL Lock (Output Events)" "Default (NoWait)" -process "Generate Programming File"
  project set "Release Write Enable (Output Events)" "Default (6)" -process "Generate Programming File"
  project set "Enable Internal Done Pipe" "false" -process "Generate Programming File"
  project set "Create Binary Configuration File" "false" -process "Generate Programming File"
  project set "Enable Debugging of Serial Mode BitStream" "false" -process "Generate Programming File"
  project set "Other Bitgen Command Line Options" "" -process "Generate Programming File"

  #project set "Compiled Library Directory" "\$XILINX/<language>/<simulator>"
  #project set "Maximum Signal Name Length" "20" -process "Generate IBIS Model"
  #project set "Show All Models" "false" -process "Generate IBIS Model"
  #project set "Target UCF File Name" "" -process "Back-annotate Pin Locations"
  #project set "Output File Name" " name_output " -process "Generate IBIS Model"

  puts "   $myScript: project property values set."
  puts ""

}

#
# sim
#
proc sim {} {

  # global vars
  global project_name
  global myScript
  global wcfg_file
  global fuse_file
  global working_dir
  global top_tb
  global isim_proj
  global sb_lib_files
  global wb_lib_files
  global soc_lib_files
  global tool_lib_files
  global config_lib_files
  global tb_files
  global top_hw
  global tb_files
  global test_bench_name
  global sim_tcl_file
  global tb_dir
  global top_path

  puts ""
  puts " -------------------------------------------------------------"
  puts "                     Starting simulation...                   "
  puts " -------------------------------------------------------------"
  puts ""
  
  puts "   $myScript: starting..."
  puts ""

  # set up path
  cd $working_dir

  # build ISIM project
  if {[catch {set f_id [open $isim_proj w]} msg]} { 
    puts "Can't create $isim_proj"
    puts $msg
    puts ""

    # keep hierarchy
    cd $top_path/
    close $f_id

    return false
  }

  puts ""
  puts " -------------------------------------------------------------"
  puts "                     Adding source files...                   "
  puts " -------------------------------------------------------------"
  puts ""
  
  #
  # HARDWARE FILES
  #

  foreach filename $tool_lib_files { 
    if { ! [file_exist $filename] } {
      close $f_id
      return false
    }

    puts "  vhdl tool_lib $filename"
    puts $f_id "vhdl tool_lib $filename"
  }

  foreach filename $wb_lib_files { 
    if { ! [file_exist $filename] } {
      close $f_id
      return false
    }

    puts "  vhdl wb_lib $filename"
    puts $f_id "vhdl wb_lib $filename"
  }

  foreach filename $sb_lib_files { 
    if { ! [file_exist $filename] } {
      close $f_id
      return false
    }

    puts "  vhdl sb_lib $filename"
    puts $f_id "vhdl sb_lib $filename"
  }

  foreach filename $soc_lib_files { 
    if { ! [file_exist $filename] } {
      close $f_id
      return false
    }

    puts "  vhdl soc_lib $filename"
    puts $f_id "vhdl soc_lib $filename"
  }

  foreach filename $config_lib_files { 
    if { ! [file_exist $filename] } {
      close $f_id
      return false
    }

    puts "  vhdl config_lib $filename"
    puts $f_id "vhdl config_lib $filename"
  }

  #
  # SIMULATION FILES
  #

  # tb files
  foreach filename $tb_files {
    if { ! [file_exist $filename] } {
      close $f_id
      return false
    }
    puts "  vhdl work $filename"
    puts $f_id "vhdl work $filename"
  }

  # top tb file
  if { ! [file_exist $top_tb] } {
    close $f_id 
    return false
  }
  puts "  vhdl work $top_tb"
  puts $f_id "vhdl work $top_tb"
  
  close $f_id
  
  puts ""
  puts " -------------------------------------------------------------"
  puts "                       Running fuse...                        "
  puts " -------------------------------------------------------------"
  puts ""
  
  # build simulation executable
  if {[catch {set f_id [open $fuse_file w]} msg]} {
    puts "  $myScript: can't create $fuse_file"
    puts $msg
    puts ""

    # keep hierarchy
    cd $top_path/

    close $f_id

    return false
  }

  # create fuse config
  set path_test_bench work.$test_bench_name
  puts $f_id "-L tool_lib -L wb_lib -L sb_lib -L soc_lib -ise $project_name.ise -nodebug -intstyle ise -incremental -o $project_name.exe -prj $isim_proj $path_test_bench"    
  close $f_id

  # run fuse
  if {[catch { 
    set fuse_p [open "|fuse -f $fuse_file" r]
    while {![eof $fuse_p]} { 
      gets $fuse_p line 
      puts $line
    }

    close $fuse_p
    
  } msg]} {
    if {[string match "NONE" $errorCode]} {
      puts $msg
      puts ""
    } else {
      puts "  $myScript: can't run fuse..."
      puts $msg
      puts ""

      # keep hierarchy
      cd $top_path/

      return false	
    }
  }

  puts ""
  puts " -------------------------------------------------------------"
  puts "                       Starting ISim...                       "
  puts " -------------------------------------------------------------"
  puts ""

  # start isim
  set wdb_file wdb_file_$project_name
  if { [catch {set isim_p [open "|./$project_name.exe -gui -tclbatch $tb_dir/$sim_tcl_file -view $wcfg_file -wdb wdb_file.wdb" r]} msg]} {
    puts "  $myScript: can't run isim..."
    puts $msg
    puts ""

    # keep hierarchy
    cd $top_path/
	
    close $isim_p

    return false
  }

  puts ""
  puts " -------------------------------------------------------------"
  puts "                         Completed!!!!                        "
  puts " -------------------------------------------------------------"
  puts ""

  # keep hierarchy
  cd $top_path/
	
  close $isim_p
  
  return true
}

#
# isim
# 
proc isim {} {

  # global var
  global myScript

  puts "  $myScript: starting ISIM..."
  if {[catch {set isim_p [open "|isimgui" r]}]} {
    puts "  $myScript: can't launch ISIM..."
    close $isim_p
        
    return false
  }
  
  # for display
  puts ""
  
  close $isim_p
  
  return true
}

#############################################################
#-----------------------------------------------------------#
#                                                           #
#                           MAIN                            #
#                                                           #
#-----------------------------------------------------------#
#############################################################

#
# main
#
proc main {} {

  if { [llength $::argv] == 0 } {
    show_help

    return true
  }

  foreach option $::argv {

    switch $option {
      "show_help"           { show_help }
      "clean"               { clean }
      "make"                { make }
      "all"                 { all }
      "rebuild_all"         { rebuild_all }
      "check"               { check }
      "rs"                  { rs }
      "rp"                  { rp }
      "rb"                  { rb }
      "down"                { down }
      "add"                 { add }
      "sim"                 { sim }
      "isim"                { isim }
      default               { puts "unrecognized option: $option"; show_help }
    }
  }
}

if {$tcl_interactive} {
    show_help
} else {
  if {[catch {main} result]} {
    puts "$myScript failed: $result."
  }
}

