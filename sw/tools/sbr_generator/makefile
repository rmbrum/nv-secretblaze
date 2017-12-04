#############################################################
#-----------------------------------------------------------#
#                                                           #  
# Company       : LIRMM                                     #
# Engineer      : Lyonel Barthe                             #
# Version       : 1.0                                       #
#                                                           #
# Revision History :                                        #
#                                                           #
#   Version 1.0 - 1/02/2010 by Lyonel Barthe                #
#       Initial Release                                     #
#                                                           #
#-----------------------------------------------------------#
#############################################################

CC=g++
CFLAGS= 
LDFLAGS=
EXEC=gen

all: $(EXEC)

gen: main.o
	$(CC) -o gen main.o $(LDFLAGS)

main.o: main.cc
	$(CC) -o main.o -c main.cc $(CFLAGS)

clean:
	rm -rf *.o

mrproper: clean
	rm -rf $(EXEC)



