/*
This is a direct memory-scanning solution for real-time
monitoring Nihon Kohden EEG-1200 EEG signal. This is a C# 
program, add it to a C# project or compile directly.

NOTE 1: The program uses a search for patterns of [30on-
35off] 2-byte words characteristic of [what appears to be] 
screen or data writing buffer in neurofax program. Thus, 
the program extracts directly the data as they are shown
by neurofax program on the screen. To use the program, 
set the "display scale" in neurofax program as small as
possible [1 microvolt]. Note also that this program may
break if the 30on-35off structure of the screen buffer
will break due to any reason.

NOTE 2: The program sends data to a variable in Matlab
via Matlab COM interface. For that, receiving Matlab
session needs to be started via with -automation flag
via "Matlab.exe -automation". If receiving session is
not started with -automation flag before starting this
program, a new COM-automation server Matlab session 
will be launched automatically by Windows (which is
not necessarily a desirable outcome).

(c) Y. Mishchenko, M. Kaya (2016)
*/
﻿using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Collections;
using System.Threading;

using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace mdriver
{
    class mdriver
    {
        // some constants (state of memory pages)
        const int PROCESS_QUERY_INFORMATION = 0x0400;
        const int MEM_COMMIT = 0x00001000;
        const int MEM_FREE = 0x00010000;
        const int PAGE_READWRITE = 0x04;
        const int PROCESS_WM_READ = 0x0010;

        // DLL imports
        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll")]
        public static extern bool ReadProcessMemory(int hProcess, int lpBaseAddress, short[] lpBuffer, int dwSize, ref int lpNumberOfBytesRead);

        [DllImport("kernel32.dll")]
        static extern void GetSystemInfo(out SYSTEM_INFO lpSystemInfo);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern int VirtualQueryEx(IntPtr hProcess, IntPtr lpAddress, out MEMORY_BASIC_INFORMATION lpBuffer, uint dwLength);


        // some structs
        public struct MEMORY_BASIC_INFORMATION
        {
            public int BaseAddress;
            public int AllocationBase;
            public int AllocationProtect;
            public int RegionSize;
            public int State;
            public int Protect;
            public int lType;
        }

        public struct SYSTEM_INFO
        {
            public ushort processorArchitecture;
            ushort reserved;
            public uint pageSize;
            public IntPtr minimumApplicationAddress;
            public IntPtr maximumApplicationAddress;
            public IntPtr activeProcessorMask;
            public uint numberOfProcessors;
            public uint processorType;
            public uint allocationGranularity;
            public ushort processorLevel;
            public ushort processorRevision;
        }


        /*
         Neurofax-write-buffer search algorithm [pattern based]
         for each memory offset i=n*512 words do
            for M=5 blocks of 65 words starting with i do
              calculate the number of​​ ​continuous​ zeros in the end of the block (ignoring last word) -> s(m)
              calculate the total number of zeros in the block (ignoring last word) -> c(m)
            end do
             
            calculate max(abs(s(:)-s(1))) -> B1
            calculate max(abs(c(:)-​s​(1))) -> B2
         
            if (s(1)<50 and s(1)>20 and B1<=2 and B2<=2) then
               add i as the candidate for buffer's starting address
            end if
         end do
        */
        public static int checkBuffer(short[] buf, int maxBytes)
        {
            for (int offset = 0; offset + 65 * 5 < maxBytes; offset += 512)
            {
                // calculate zeros at the end of each of five 65-word blocks
                int[] s = new int[5];

                for (int m = 0; m < 5; m++)
                {
                    for (int i = 64; i >= 0; i--)
                    {
                        if (buf[offset + m * 65 + i] == 0) s[m]++; else break;
                    }
                }

                int s0 = s[0];

                // calculate total zeros at the end of each of five 65-word blocks
                int[] c = new int[5];

                for (int m = 0; m < 5; m++)
                {
                    for (int i = 0; i < 65; i++)
                    {
                        if (buf[offset + m * 65 + i] == 0) c[m]++;
                    }
                }

                // calculate B1 and B2
                for (int m = 0; m < 5; m++)
                {
                    s[m] = Math.Abs(s[m] - s0);
                    c[m] = Math.Abs(c[m] - s0);
                }

                int B1 = s.Max();
                int B2 = c.Max();

                // pattern condition check
                if (s0 < 50 & s0 > 20 & B1 <= 2 & B2 <= 2)
                {
                    // if here, found the pattern, return offset
                    return offset;
                }
            }

            // if here, not found the pattern => return -1
            return -1;
        }

        static Stopwatch stopWatch = new Stopwatch();

        /*
         Timed log write to console.
        */
        public static void logOut(String s)
        {
            TimeSpan ts = stopWatch.Elapsed;

            string elapsedTime = String.Format("{0:00}:{1:00}:{2:00}.{3:00}",
                             ts.Hours, ts.Minutes, ts.Seconds,
                             ts.Milliseconds / 10);

            Console.WriteLine(elapsedTime + ": " + s);
        }

        public static void Main()
        {
            //WARNING:
            //THIS PROGRAM CURRENTLY HAS NO CHECKING FOR ERROR CONDITIONS;
            //THIS MAY MAKE IT WORK UNSTABLE OR FAIL MYSTERIOUSLY

            String E12Acq = "E12Acq";    // name of the process to track [neurofax]
            String str = "";

            // get process min & max address [32/64bit system dependent]
            SYSTEM_INFO sys_info = new SYSTEM_INFO();
            GetSystemInfo(out sys_info);

            // get handle to MATLAB COM server
            MLApp.MLApp matlab = new MLApp.MLApp();

            // structure for holding memory page information
            MEMORY_BASIC_INFORMATION mem_basic_info = new MEMORY_BASIC_INFORMATION();
         
            // attach to process
            Process process = Process.GetProcessesByName(E12Acq)[0];
            IntPtr processHandle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_WM_READ, false, process.Id);
            Console.WriteLine("Attached to " + E12Acq);

            long bufferPage = -1;  // write-buffer's page address
           
            // SEARCH LOOP
            // do this only once, THE WRITE BUFFER PAGE APPEARS TO NEVER CHANGE
            stopWatch.Start();
            while(bufferPage == -1)
            {
                // pause loop
                Thread.Sleep(100);

                // try to get buffer for max 1 minutes
                if (stopWatch.Elapsed.TotalMinutes > 1) break;

                // get min/max memory addresses from sys_info
                IntPtr proc_min_address = sys_info.minimumApplicationAddress;
                IntPtr proc_max_address = sys_info.maximumApplicationAddress;

                long proc_min_address_l = (long)proc_min_address;
                long proc_max_address_l = (long)proc_max_address;

                // read process memory
                int bytesRead = 0;
                while (proc_min_address_l < proc_max_address_l)
                {
                    // 28 = sizeof(MEMORY_BASIC_INFORMATION)
                    VirtualQueryEx(processHandle, proc_min_address, out mem_basic_info, 28);

                    if (mem_basic_info.State == MEM_FREE)
                    {
                        if (mem_basic_info.RegionSize > 10000000)
                        {
                            // if here, means we hit first large free space in memmap,
                            // if not found buffer untill now, buffer is not found
                            continue;
                        }
                    }
                    else
                    {
                        if (mem_basic_info.Protect == PAGE_READWRITE && mem_basic_info.State == MEM_COMMIT)
                        {
                            // read current memory page if the page is committed and read-write
                            short[] buf = new short[mem_basic_info.RegionSize / sizeof(short)];
                            ReadProcessMemory((int)processHandle, mem_basic_info.BaseAddress, buf, mem_basic_info.RegionSize, ref bytesRead);
                            bytesRead = bytesRead / sizeof(short);

                            // check for presence of buffer pattern, if found the pattern => break out
                            if (checkBuffer(buf, bytesRead) >= 0)
                            {
                                bufferPage = mem_basic_info.BaseAddress;
                                logOut(String.Format("found buffer at page: {0} ", bufferPage));
                                break;
                            }
                        }
                    }

                    // step memory page for next page
                    proc_min_address_l += mem_basic_info.RegionSize;
                    proc_min_address = new IntPtr(proc_min_address_l);
                }
            }

            // ACQUSITION LOOP
            while (bufferPage >= 0)
            {
                // Break condition, 10 minutes [TODO ENABLE BREAKING FROM MATLAB!!!!]
                if (stopWatch.Elapsed.TotalMinutes > 10) break;

                // get write-buffer's page as IntPtr
                IntPtr buf_min_address = new IntPtr(bufferPage);

                // get page's info
                VirtualQueryEx(processHandle, buf_min_address, out mem_basic_info, 28);

                short[] buf = new short[mem_basic_info.RegionSize / sizeof(short)];
                int bytesRead = 0;

                // read buffer's page
                ReadProcessMemory((int)processHandle, mem_basic_info.BaseAddress, buf, mem_basic_info.RegionSize, ref bytesRead);
                bytesRead = bytesRead / sizeof(short);

                // send buffer's page to Matlab
                double[] sendData = new double[bytesRead];
                for (int i = 0; i < bytesRead; i++)  sendData[i] = Convert.ToDouble(buf[i]);
                matlab.PutFullMatrix("DATA", "base", sendData, sendData);

                double[] send = { 0, 0, bytesRead }; 
                matlab.PutFullMatrix("POS", "base", send, send);

                // logging
                str = String.Format("Send {0} data",bytesRead);
                logOut(str);

                // sleep 10 msec
                Thread.Sleep(10);

            } // end main loop

            Console.ReadLine();
        } // end main() function

    } // end mdriver class

}
