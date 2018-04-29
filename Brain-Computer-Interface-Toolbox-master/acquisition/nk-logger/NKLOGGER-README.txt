SEQUENCE OF STARTING MATLAB NKLOGGER INTERFACE:
1. Start Neurofax and start taking data on screen
1.a Neurofax can be minimized after data is on
1.b Make sure Neurofax is taking real (noisy) data (neither calibration nor data-off regime) before proceeding to steps 3 and 4.

2. Set Neurofax Sensitivity (Sens) to 1 uV 

3. Start MATLAB	with automation server using NKLOGGER-MATLAB shortcut
3.a Matlab with automation server will start MINIMIZED, find it in the task bar and maximize
3.b NKDATA will be created and made global automatically if Matlab started via NKLOGGER-MATLAB shortcut

4. Navigate MATLAB's current directory to C:\Users\NEURO\Desktop by executing in command window:
cd C:\Users\NEURO\Desktop

5. Start MDRIVER.EXE using NKLOGGER-MDRIVER.EXE shortcut
5.a mdriver.exe should find Neurofax's screen buffer page and start sending data
5.b if mdriver.exe cannot find the buffer page, try producing some noise eeg data in neurofax by swiping hand near EEG receiver box
5.c to stop mdriver use CTRL+C after the experiment concludes and *BEFORE* closing either MATLAB or NEUROFAX windows

6. Proceed to configure and run nklogger or nkiui in created Matlab automation server window 
(to be covered later)

Example for nklogger:
nk=nklogger(3000);
o=nk.run;

Example for nkiui:
(in Matlab automation server window)
nk=nkiui(600);
nk.prepare_prg
o=nk.run;

7. Save resulting data. 
!!! During UI testing phase, after the experiment concludes save both output o and UI object nk
save [experiments-datafile-name]-nk.mat nk
save [experiments-datafile-name]-o.mat o