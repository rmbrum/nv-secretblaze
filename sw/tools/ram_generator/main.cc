// ADAC Group - LIRMM - University of Montpellier / CNRS
// Lyonel Barthe
// Updated on 16/01/2012
// Original version 01/02/2010

// Generate data ram files 

#include <string>
#include <iostream>
#include <fstream>
#include <stdlib.h>

static std::string charToString(const char &c) // tank function
{
  std::string s;
  
  switch (c) 
  {
    case '0':
      s = "0000";
      break;
    case '1':
      s = "0001";
      break;
    case '2':
      s = "0010";
      break;
    case '3':
      s = "0011";
      break;
    case '4':
      s = "0100";
      break;
    case '5':
      s = "0101";
      break;
    case '6':
      s = "0110";
      break;
    case '7':
      s = "0111";
      break;
    case '8':
      s = "1000";
      break;
    case '9':
      s = "1001";
      break;
    case 'a':
      s = "1010";
      break;
    case 'b':
      s = "1011";
      break;
    case 'c':
      s = "1100";
      break;
    case 'd':
      s = "1101";
      break;
    case 'e':
      s = "1110";
      break;
    case 'f':
      s = "1111";
      break;
    default:
      std::cerr << "Error in charToString!" << std::endl;
      s = "0000";
      break;
  }	

  return s;
}

int main (int argc, char * const argv[]) 
{
		
  std::ifstream inFile;          // input file
  std::ofstream outFile;         // 32-bit ram file format
  std::ofstream outFileh;        // 32-bit ram file format (hex format)
  std::ofstream outFile1;        // 8-bit ram file format
  std::ofstream outFile2;        // 8-bit ram file format
  std::ofstream outFile3;        // 8-bit ram file format
  std::ofstream outFile4;        // 8-bit ram file format	
  std::ifstream::pos_type size;  // rom file size
  char* mem;                     // rom buffer
  char buffer[256];
  int DATA_SIZE = 0;
	
  // display
  std::cout << argv[0] << " " << argv[1] << " " << argv[2] << std::endl;
  	
  // unsafe acq
  inFile.open(argv[1], std::ios::in|std::ios::binary|std::ios::ate);
  DATA_SIZE = (int)strtol(argv[2],NULL,10);
	
  // read file
  if(inFile.is_open())
  {
    size = inFile.tellg();
    mem = new char[(int)size];
    inFile.seekg(0,std::ios::beg);
    inFile.read(mem,size);
    inFile.close();
    // std::cout << "Binary file read" << std::endl;
  }
  else
  {
    std::cout <<"Can't open binary file!" << std::endl;
    return -1;
  }

  outFileh.open("hex_mem.data", std::ios::out);
  outFile.open("local_mem.data", std::ios::out);
  outFile1.open("local_mem1.data", std::ios::out);
  outFile2.open("local_mem2.data", std::ios::out);
  outFile3.open("local_mem3.data", std::ios::out);
  outFile4.open("local_mem4.data", std::ios::out); 

  // TODO: is_open() etc.
	
  for(int i=0;i<DATA_SIZE;i++)
  {
    sprintf(buffer,"%.2x",(mem[i] & 0xFF));
    outFile << charToString(buffer[0]);
    outFile << charToString(buffer[1]);	
    outFileh << (buffer[0]);
    outFileh << (buffer[1]);

    // LSB 8-bit file ...
    if((i+1)%4 == 0) 
    {
      outFile1 << charToString(buffer[0]);
      outFile1 << charToString(buffer[1]);
      outFile1 << std::endl;
      outFile  << std::endl;    
      outFileh << std::endl;    
    }   

    if((i+2)%4 == 0)
    {
      outFile2 << charToString(buffer[0]);
      outFile2 << charToString(buffer[1]);
      outFile2 << std::endl;
    }

    if((i+3)%4 == 0)
    {
      outFile3 << charToString(buffer[0]);
      outFile3 << charToString(buffer[1]);
      outFile3 << std::endl;
    }

    // ... MSB 8-bit file
    if((i+4)%4 == 0)
    {				
      outFile4 << charToString(buffer[0]);
      outFile4 << charToString(buffer[1]);
      outFile4 << std::endl;     
    }
  }

  // close files
  outFileh.close();
  outFile.close();  
  outFile1.close();
  outFile2.close();
  outFile3.close();
  outFile4.close();

  // std::cout << "RAM files created" << std::endl;
	
  // free memory
  delete[] mem;	
	
  return 0;
}

