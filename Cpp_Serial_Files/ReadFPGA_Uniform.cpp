#include<windows.h>
#include<iostream>
#include<fstream>
#include<string>
#include<chrono>
#include<bitset>

int main()
{

	//variables for handling data
	std::string binstring;
	std::string::size_type sz = 0;
	
	long double LDcarry = long double(std::powl(2.0,63.0));
	long double LDmaxval = long double(std::powl(2.0,64.0) - 1.0);
	
	int cnt = 0;
	int NoOfBTRead = 8;
	
	unsigned __int64 initime;
	unsigned __int64 runtime;
	auto start = std::chrono::high_resolution_clock::now();
	auto finish = std::chrono::high_resolution_clock::now();

	//variables for handling serial comms
    HANDLE hComm;
    std::string port_name = "COM6";  //change port name
	//If you send "U" it will be uniform
	//If you send "G" is will be gaussian
	//If you send "B" it will continue with the previous setting
	//or default to uniform
    unsigned char write_buffer[] = "U";
    unsigned char read_buffer[1];
	DWORD dNoOFBytestoRead = 1;
    DWORD dNoOFBytestoWrite = 1;         	// # of bytes to write into the port
    DWORD dNoOFBytestoW = 1;         		// # of bytes to write into the port
    DWORD dNoOfBytesWritten;     			// # of bytes written to the port
    DWORD dNoOfBytesW;     					// # of bytes written to the port
    DWORD bytes_read = 0;

	//open file to output data for analysis in other software
	std::ofstream datafile;
	datafile.open("TestData.txt");
	//you probably wont see 64 digits but this makes sure you get the maximum bang per buck
	datafile.precision(64);

	//Create and open port
    hComm = CreateFileA(port_name.c_str(),  //port name
        GENERIC_READ | GENERIC_WRITE, 		//Read/Write
        0,                            		// # Sharing
        NULL,                         		// # Security
        OPEN_EXISTING,						// Open existing port only
        0,            						// Non Overlapped I/O
        NULL);        						// Null for Comm Devices

    if (hComm == INVALID_HANDLE_VALUE)
    {
        std::cerr << "Error, unable to open serial port\n";
        return -1;
    }
    else
        std::cerr << "Opened serial port successfully!\n";

    DCB dcbSerialParams = { 0 }; // Initializing DCB structure
    dcbSerialParams.DCBlength = sizeof(dcbSerialParams);
    GetCommState(hComm, &dcbSerialParams);

	//Your baud rates are below (these three have been tested)
    //dcbSerialParams.BaudRate = CBR_9600;  // Setting BaudRate = 9600
	//dcbSerialParams.BaudRate = CBR_115200;  // Setting BaudRate = 115200
	dcbSerialParams.BaudRate = 921600;  // Setting BaudRate = 921600 , doesn't seem to work!
    dcbSerialParams.ByteSize = 8;         // Setting ByteSize = 8
    dcbSerialParams.StopBits = ONESTOPBIT;// Setting StopBits = 1
    dcbSerialParams.Parity = NOPARITY;  // Setting Parity = None
    SetCommState(hComm, &dcbSerialParams);

	//timer
	using namespace std::chrono;
	initime = duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
	for (int j = 0; j < 10000; j++)
	{
	binstring = "";
	//for timing the read/write times
	//start = high_resolution_clock::now();

	//write to the FPGA to tell it to send data
    dNoOFBytestoWrite = sizeof(write_buffer);
	do
	{
    WriteFile(hComm,        // Handle to the Serial port
        write_buffer,     // Data to be written to the port
        dNoOFBytestoWrite,  //No of bytes to write
        &dNoOfBytesWritten, //Bytes written
        NULL);
	} while (dNoOfBytesWritten <= 0);
	
	//read a certain number of times
	//Do this instead of a while loop of 8 bytes so that you can
	//catch each byte and modify or rearrange it if necessary.
	//Here, we don't need to do that.
    for (int m = 0; m < NoOfBTRead; m++)
    {
        ReadFile(hComm,      //Handle of the Serial port
            &read_buffer,       //Temporary character
            dNoOFBytestoRead,//Size of TempChar
            &bytes_read,    //Number of bytes read
            NULL);
		binstring = std::bitset<8>(read_buffer[0]).to_string() + binstring;
    }
	
	//if you want to print the bitstring to check things
	//std::cout << binstring << std::endl;
	//if you want constant timestamps
	//start = high_resolution_clock::now();
	//std::cout << "Time:      " << (duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count() - initime)/1000.0 << std::endl;
	
	//if you use stoll for a number that is >2^63 it will crash
	//this gets around that while maintaining precision
    if (binstring[0] == '0')
	{
		datafile << long double(std::stoll(binstring,nullptr,2))/LDmaxval;
		datafile << "\n";
	}
	else
	{
		binstring[0] = '0';
		datafile << (LDcarry + long double(std::stoll(binstring,nullptr,2)))/LDmaxval;
		datafile << "\n";
	}
	
	//Timestamp print
	//std::cout << "Time:      " << (duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count() - initime)/1000.0 << std::endl;

	//Print so that you can see that progress is being made
	cnt += 1;
	if (cnt % 1000 == 0)
	{
		std::cout << "Iteration: " << cnt << std::endl;
		std::cout << "Time:      " << (duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count() - initime)/1000.0 << std::endl;
	}
	}
	runtime = duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count() - initime;
	std::cout << "\nRun Time : " << runtime/1000.0 << " seconds." << std::endl;
	
	datafile.close();

	//hang the program for the user to see execution time
	int dum = 0;
	std::cin >> dum;
    CloseHandle(hComm);//Closing the Serial Port

    return 0;
}
