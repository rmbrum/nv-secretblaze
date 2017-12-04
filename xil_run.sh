#!/bin/bash

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

LOG_FILE=log/`date +%H%M%S`_`date +%d%m%y`.txt
(

#############################################################
#-----------------------------------------------------------#
#                                                           #  
# Company       : LIRMM                                     #
# Engineer      : Lyonel Barthe                             #
# Version       : 1.4                                       #
#                                                           #
# Revision History :                                        #
#                                                           #
#   Version 1.4 - 08/2012 by Lyonel Barthe                  #
#       Changed BSP management                              #
#                                                           #
#   Version 1.3 - 28/10/2011 by Lyonel Barthe               #
#       Changed path management                             #
#                                                           #
#   Version 1.2 - 26/05/2011 by Lyonel Barthe               #
#       Cleaned the code                                    #
#                                                           #
#   Version 1.1 - 05/10/2010 by Lyonel Barthe               #
#       Clean up version                                    #
#                                                           #
#   Version 1.0 - 26/04/2010 by Lyonel Barthe               #
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
# ./xil_run.sh     <-- default settings                     #
#                                                           #
# ./xil_run.sh ds3 <-- Digilent Spartan-3 STK settings      #
#                                                           #
# ./xil_run.sh ds6 <-- Digilent Spartan-6 ATLYS settings    #
#                                                           #
#-----------------------------------------------------------#
#############################################################

#############################################################
#-----------------------------------------------------------#
#                                                           #
#                        HIERARCHY                          #
#                                                           #
#                                                           #
#   root \                                                  #
#        | bin           <-- BIN files                      #
#        | hw            <-- HW files                       #
#        | sw            <-- SW files                       #
#        | log           <-- LOG files                      #
#        - xil_run.sh    <-- MAIN sh script                 #
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

#-----------------------------------------------------------#
#                                                           #
#                          HEADER                           #
#                                                           #
#                                                           #

clear

echo "Starting the SecretBlaze script for Xilinx's tools..."
echo "*****************************************************"
echo "ADAC Group - LIRMM - University of Montpellier / CNRS"
echo "*****************************************************"
echo "Contact: adac@lirmm.fr"
#                                                           #
#-----------------------------------------------------------#	

#-----------------------------------------------------------#
#                                                           #
#                        USER PATH                          #
#                                                           #
#                                                           #

YOUR_LIN_XIL_TOOL_PATH=/opt/Xilinx/14.1/ISE_DS

#                                                           #
#-----------------------------------------------------------#	

#-----------------------------------------------------------#
#                                                           #
#                     PLATFORM SETTINGS                     #
#                                                           #
#                                                           #
u_system=`(uname -s) 2>/dev/null` || u_system=unknown
u_arch=`(uname -m) 2>/dev/null` || u_arch=unknown

echo "Checking hardware..."

case "$u_system:$u_arch" in
		
  Linux:x86_64|Linux:ia64)
    echo "Linux platform detected (64-bits)"
    BASE_DIR=$(readlink -f $(dirname "$0"))
    SBR_GEN_APP="sbr_gen_lin"
    BIN_2_RAM_APP="ram_gen_lin"
    DOXY_APP="doxygen_lin"
    if [ -d "$YOUR_LIN_XIL_TOOL_PATH" ] ; then
      echo "Path of Xilinx's tools: $YOUR_LIN_XIL_TOOL_PATH"
      echo "Sourcing Xilinx's scripts..."
      source "$YOUR_LIN_XIL_TOOL_PATH/settings64.sh" $YOUR_LIN_XIL_TOOL_PATH
    else
      echo "Can't find Xilinx's tools!"
      echo "Exiting..."
      exit 1
    fi
    ;;

  Linux:i386|Linux:i486|Linux:i586|Linux:i686)
    echo "Linux platform detected (32-bits)"
    BASE_DIR=$(readlink -f $(dirname "$0"))
    SBR_GEN_APP="sbr_gen_lin"
    BIN_2_RAM_APP="ram_gen_lin"
    DOXY_APP="doxygen_lin"
    if [ -d "$YOUR_LIN_XIL_TOOL_PATH" ] ; then
      echo "Path of Xilinx's tools: $YOUR_LIN_XIL_TOOL_PATH"
      echo "Sourcing Xilinx's scripts..."
      source "$YOUR_LIN_XIL_TOOL_PATH/settings32.sh" $YOUR_LIN_XIL_TOOL_PATH
    else
      echo "Can't find Xilinx's tools!"
      echo "Exiting..."
      exit 1
    fi
    ;;

  Cygwin:*) 	
    echo "Windows/Cygwin platform detected"
    echo "No longer supported!"
    exit 0
    ;;

  Darwin:*) 
    echo "OS X platform detected"
    echo "Not supported!"
    exit 0
    ;;

  *) 
    echo ""
    echo "Error... Unknown system!"
    exit 0
    ;;
	
esac

#                                                           #
#-----------------------------------------------------------#

#-----------------------------------------------------------#
#                                                           #
#                      SCRIPT SETTINGS                      #
#                                                           #
#
   
# main dirs
HW_DIR="$BASE_DIR/hw"
SW_DIR="$BASE_DIR/sw"
BIN_DIR="$BASE_DIR/bin"

# hw sub-dirs
HW_DOXY_DIR="$HW_DIR/docs/doxygen"
DESIGN_DIR="$HW_DIR/designs"

# sw sub-dirs
SW_APP_DIR="$SW_DIR/apps"
SW_DOXY_DIR="$SW_DIR/docs/doxygen"
SBR_DIR="$SW_DIR/sbr"

# ds3 config
if [ "$1" = "ds3" ] ; then
  USER_APP_DIR="bootloader"
  USER_DESIGN_DIR="digilent_s3_starter_board"
  USER_TOP_FILE="xc3s1000_top"
  USER_TCL_FILE="xc3s1000"
  USER_BMM_FILE="lm_16ko"
  USER_LOCAL_MEM_SIZE=16384 
# ds6 config 
elif [ "$1" = "ds6" ] ; then
  USER_APP_DIR="bootloader"
  USER_DESIGN_DIR="digilent_s6_atlys_board"
  USER_TOP_FILE="xc6slx45_top"
  USER_TCL_FILE="xc6slx45"
  USER_BMM_FILE="lm_16ko"
  USER_LOCAL_MEM_SIZE=16384  
# default config  
else
  USER_APP_DIR="bootloader"
  USER_DESIGN_DIR="digilent_s3_starter_board"
  USER_TOP_FILE="xc3s1000_top"
  USER_TCL_FILE="xc3s1000"
  USER_BMM_FILE="lm_16ko"
  USER_LOCAL_MEM_SIZE=16384  
fi

#                                                           #
#-----------------------------------------------------------#

#############################################################
#-----------------------------------------------------------#
#                                                           #
#                     IMPLEMENTATION                        #
#                                                           #
#-----------------------------------------------------------#
#############################################################

echo "Settings done"
echo "Press enter..."
IFS="\n"
read dummy
clear

#-----------------------------------------------------------#
#                                                           #
#                          MENU                             #
#                                                           #

sb_menu () {

  echo ""
  echo "~ SecretBlaze Main Script ~"
  echo `date` 	
  echo ""
  echo "  Hardware Commands"
  echo "    a  Set design configuration"
  echo "    b  Set local memory size"
  echo "    c  Make new project"
  echo "    d  Run synthesize"
  echo "    e  Run place & route"
  echo "    f  Run bitstream generation"
  echo "    g  Download last bitstream"
  echo "    h  Rebuild all"
  echo "    i  Start the simulation"
  echo ""
  echo "  Software Commands"
  echo "    j  Set application directory"
  echo "    k  Compile user app"
  echo "    l  Compile user app, then generate local memory files"
  echo "    m  Compile user app, update local memories, then download"
  echo "    o  Compile user app, then generate sbr file"
  echo "    s  Compile all + sbr files"  
  echo ""
  echo "  Miscellaneous"
  echo "    p  Project statistics"
  echo "    q  Run HW doxygen documentation"
  echo "    r  Run SW doxygen documentation"
  echo "    x  Exit"
  echo "    z  Clean project"
  echo ""
  echo "  User design:           $USER_DESIGN_DIR"
  echo "  User top level entity: $USER_TOP_FILE"
  echo "  User TCL file:         $USER_TCL_FILE"
  echo "  User BMM file:         $USER_BMM_FILE"
  echo "  User local mem size:   $USER_LOCAL_MEM_SIZE bytes"     
  echo "  User app:              $USER_APP_DIR"
  echo ""
  echo -n "  > "

}

#                                                           #
#-----------------------------------------------------------#

#
# end function OK
#
end_func () {
  echo ""
  echo "Press enter..."
  IFS="\n"
  read dummy
  clear
}

#
# end function error
#
end_err() {
  echo ""
  echo "Try again... press enter"
  IFS="\n"
  read dummy
  clear
}

#
# clean function
#
clean_func() {

  echo "Removing doxygen files..."
  cd "$HW_DOXY_DIR"
  if [ -d html ] ; then
    rm -r html
  fi
  if [ -d latex ] ; then
    rm -r latex
  fi  
  cd "$SW_DOXY_DIR"
  if [ -d html ] ; then
    rm -r html
  fi
  if [ -d latex ] ; then
    rm -r latex
  fi 

  # keep hierarchy
  cd "$BASE_DIR"
  echo "Removing other files..."
  # remove .DS_Store files
  find ./ -name '.DS_Store' -exec rm '{}' \; -print
  # remove ~ files 
  find ./ -name '*~' -exec rm '{}' \; -print -or -name ".*~" -exec rm {} \; -print

}

#
# generate hw doxygen 
#
hw_doxy () {

  echo ""
  echo " ------------------------------------------------------------- "
  echo "                           Doxygen"
  echo " ------------------------------------------------------------- "
  echo ""
  
  # generate html/latex files inside the hw/docs dir
  cd "$HW_DOXY_DIR"
  "$BIN_DIR/$DOXY_APP" doxy_config
  if [ "$?" -ne '0' ] ; then
    cd "$BASE_DIR"
    return 1
  fi
  
  # keep hierarchy
  cd "$BASE_DIR"
  
  return 0	
}

#
# generate sw doxygen 
#
sw_doxy () {

  echo ""
  echo " ------------------------------------------------------------- "
  echo "                           Doxygen"
  echo " ------------------------------------------------------------- "
  echo ""
  
  # generate html/latex files inside the sw/docs dir
  cd "$SW_DOXY_DIR"
  "$BIN_DIR/$DOXY_APP" doxy_config
  if [ "$?" -ne '0' ] ; then
    cd "$BASE_DIR"
    return 1
  fi
  
  # keep hierarchy
  cd "$BASE_DIR"
  
  return 0	
}

#
# compile user project
#
comp () {

  echo ""
  echo " ------------------------------------------------------------- "
  echo "                          Compiling..."
  echo " ------------------------------------------------------------- "
  echo ""

  # compile in the app/user_tb dir
  cd "$SW_APP_DIR/$USER_APP_DIR"
  BSP_PARAM=$USER_DESIGN_DIR
  export BSP_PARAM
  make all 
  if [ "$?" -ne '0' ] ; then
    cd "$BASE_DIR"
    return 1
  fi
  
  # keep hierarchy
  cd "$BASE_DIR"
  
  return 0
}

#
# comp all 
#
comp_all () {
  
  cd "$SW_APP_DIR"
  BSP_PARAM=$USER_DESIGN_DIR
  export BSP_PARAM  
  
  tmp=$IFS
  IFS=$(echo -en "\n\b") 
  for DIR in * ; do
    
    cd $DIR
    echo ""
    echo " ------------------------------------------------------------- "
    echo "                          Compiling..."
    echo " ------------------------------------------------------------- "
    echo ""
    echo $DIR
    make all
    if [ "$?" -ne '0' ] ; then
      cd "$BASE_DIR"
      return 1
    fi  
    echo ""
 
    echo ""
    echo " ------------------------------------------------------------- "
    echo "                      Running sbr generator"
    echo " ------------------------------------------------------------- "
    echo ""
    echo $DIR      
    "$BIN_DIR/$SBR_GEN_APP" "$SW_APP_DIR/$DIR/$DIR.bin"
    if [ "$?" -ne '0' ] ; then
      return 1
    fi

    mv -v -f rom.sbr "$SBR_DIR/$USER_DESIGN_DIR/$DIR.sbr"    
    echo ""
        
    # keep hierarchy
    cd "$SW_APP_DIR"       
    
  done
  IFS=$tmp

  # keep hierarchy
  cd "$BASE_DIR"

  return 0
}

#
# sbr generator
#
sbrgen() {

  # run sbr rom generator
  "$BIN_DIR/$SBR_GEN_APP" "$SW_APP_DIR/$USER_APP_DIR/$USER_APP_DIR.bin"
  if [ "$?" -ne '0' ] ; then
    return 1
  fi

  mv -v -f rom.sbr "$SBR_DIR/$USER_DESIGN_DIR/$USER_APP_DIR.sbr"

  return 0
}

#
# bin2ram
#
bin2ram () {
    
  echo ""
  echo " ------------------------------------------------------------- "
  echo "                        Running bin2ram"
  echo " ------------------------------------------------------------- "
  echo ""

  "$BIN_DIR/$BIN_2_RAM_APP" "$SW_APP_DIR/$USER_APP_DIR/$USER_APP_DIR.bin" $USER_LOCAL_MEM_SIZE
  if [ "$?" -ne '0' ] ; then
    return 1
  fi
  
  mv -v -f "local_mem.data"  "$DESIGN_DIR/$USER_DESIGN_DIR/config_lib/ram_init_files/local_mem.data"
  mv -v -f "local_mem1.data" "$DESIGN_DIR/$USER_DESIGN_DIR/config_lib/ram_init_files/local_mem1.data"
  mv -v -f "local_mem2.data" "$DESIGN_DIR/$USER_DESIGN_DIR/config_lib/ram_init_files/local_mem2.data"
  mv -v -f "local_mem3.data" "$DESIGN_DIR/$USER_DESIGN_DIR/config_lib/ram_init_files/local_mem3.data"
  mv -v -f "local_mem4.data" "$DESIGN_DIR/$USER_DESIGN_DIR/config_lib/ram_init_files/local_mem4.data"
  mv -v -f "hex_mem.data"   "$DESIGN_DIR/$USER_DESIGN_DIR/config_lib/ram_init_files/hex_mem.data"
    
  return 0
}

#
# data2mem
#
dat2mem () {
    
  echo ""
  echo " ------------------------------------------------------------- "
  echo "                        Running data2mem..."
  echo " ------------------------------------------------------------- "
  echo ""

  data2mem -bm "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_BMM_FILE.bmm" -bd "$SW_APP_DIR/$USER_APP_DIR/$USER_APP_DIR.elf" -bt "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TOP_FILE.bit" -o b tmp.bit 
  if [ "$?" -ne '0' ] ; then
    return 1
  fi
  
  mv -v -f tmp.bit "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TOP_FILE.bit"
  
  return 0
}

#-----------------------------------------------------------#
#                                                           #
#                          MAIN                             #
#                                                           #

main_func () {
    
  while true
  do
    sb_menu
	
    read ans
	
    case $ans in

      # new design config
      a)
        echo ""
        echo "Enter the name of the design directory:"
        read the_name
        echo "Setting $the_name as new design..." 
        USER_DESIGN_DIR=$the_name
        echo "Enter the name of the top level entity:"
        read the_name
        echo "Setting $the_name as new top level entity..." 
        USER_TOP_FILE=$the_name
        echo "Enter the name of the TCL file:"
        read the_name
        echo "Setting $the_name as new TCL file..." 
        USER_TCL_FILE=$the_name
        echo "Enter the name of the BMM file:"
        read the_name
        echo "Setting $the_name as new BMM file..." 
        USER_BMM_FILE=$the_name
        end_func
        ;;

      # new local ram config
      b)
        echo ""
        echo "Warning: sb_config.vhd and linker.ld files must be correctly set up!"
        echo "Enter the local memory size in bytes:"
        read number
        echo "Setting $number bytes" 
        USER_LOCAL_MEM_SIZE=$number
        end_func
        ;;

      # make new project
      c)
        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" clean 
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" make
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" add
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;

      # run synthesize
      d)
        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" rs
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi	       

        end_func
        ;;

      # run par
      e)
        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" rp
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
      ;;

      # run bit
      f)
        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" rb
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;

      # download last bitstream
      g)
        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" down
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;

      # rebuild all
      h)
        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" rebuild_all
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;

      # run sim
      i)
        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" sim
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;

      # new app
      j)
        echo ""
        echo "Enter the name of the application directory:"
        read the_name
        echo "Setting $the_name as new project..." 
        USER_APP_DIR=$the_name
        end_func
        ;;

      # compile
      k)
        comp
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;		

      # compile + bin2ram	    
      l)
        comp 
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        bin2ram
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;

      # compile + data2mem
      m)
        comp 
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        dat2mem
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" down
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;

      # compile + sbr
      o)
        comp 
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        sbrgen 
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;
        
      # make all app
      s)
        comp_all
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi  

        end_func
        ;;              

      # stats
      p)
        echo ""
        echo "Hardware Files"
        cd "$HW_DIR/"
        find . -name '*.vhd' -o -name '*.bmm' | xargs wc -l
        echo ""
        echo "Software Files"
        cd "$SW_DIR/"
        find . -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' -o -name '*.ld' | xargs wc -l	
        echo ""
        cd "$BASE_DIR"

        end_func
        ;;

      # HW doxygen
      q)
        hw_doxy
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;

      # SW doxygen
      r) 
        sw_doxy
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        end_func
        ;;

      # exit
      x) 
        echo ""
        echo "~ Bye! ~"
        echo ""
        return 0
        ;;

      # clean
      z)
        xtclsh "$DESIGN_DIR/$USER_DESIGN_DIR/$USER_TCL_FILE.tcl" clean 
        if [ "$?" -ne '0' ] ; then
          end_err
          break
        fi

        clean_func
        end_func
        ;;

      # error
      *)
        echo ""
        echo "Invalid command!"
        echo "Try again... press enter"
        IFS="\n"
        read dummy
        clear
        ;;

    esac
	
  done
    
  # error catched
  return 1
}

# start main
main_func

# repeat until exit code
while [ "$?" -ne '0' ] 
  do
    main_func
  done

exit 0
#                                                           #
#-----------------------------------------------------------#

) | tee $LOG_FILE

