classdef nklogger < handle
  % Nihon Kohden EEG data acquisition base class.
  %
  % Usage:
  % nk=nklogger(acquisition_time,flag_dataon,flag_stateon);
  % o=nk.run
  %
  % [TO GET DATA POST-RUN]
  % o=nk.getData
  %
  % [TO RUN REPLAY]
  % nk=nklogger(replay_duration,false,true);
  % nk.replay={0,replay_buffer,0};
  % nk.run
  %
  % Change history:
  % v1.0 2016-04-15 complete
  %
  % Hooks structure:
  %  * this.run
  %     => prepare_disp()
  %     one time, create & prepare GUI window
  %     [DATA LOOP:]
  %     => preupdate_state()
  %     GUI update and related tasks BEFORE data acqusition
  %     == get data sample at most once per 100 ms
  %     => update_state()
  %     GUI update and related tasks AFTER data acqusition
  %
  % Y.Mishchenko (c) 2016
  
  
  %Hidden properties
  properties (Access = private)
    dataBuffer=[];      %last NKDATA state
    dataPointer=0;      %last read sample-pointer into NKDATA
    backoffLimit=1;     %allowed rollbacks, secs
    clockDiscrepancyLimit=10; %allowed difference in # of samples vs clock
    freqTracking=[0,0,0,0,0]; %variables involved in effective sampling 
                              %frequency estimation linear regression
  end
  
  %Hidden properties accessible to experiment implementations
  properties (Access = protected)
    gCounter=[];              %global sample counter, source-based array
    lastTime = [];            %time tracker
    lastaTime = [];           %last acquisition time (get_data)
    curTime=0;                %data-acquisition loop's in time
    loggerState=0;            %logger state
  end
  
  %Read-only public properties accessible to user
  properties(GetAccess = public, SetAccess = protected)
    name                %this instance's specific name
    marker              %array of trigger-states records
  end
  
  %Read-only public properties accessible to user
  properties (GetAccess = public, SetAccess = private)
    DataChannels      %data channels struct
    
    idtag             %experiment's unique alpha-numeric ID
    outputMatrix      %experiment's data
    outputTimes       %acquisition times of samples in outputMatrix
    effectiveFreq     %effective sampling frequency (estimated)
    nS                %total samples count
    
    dbgdata           %debug data
  end
  
  %Read-write public properties accessible to user
  properties  (Access = public)
    acqTime = 60;     %total/max acqusition time, sec
    fig = 1;          %figure number used for experiment's UI
    sampFreq = 200;   %sampling frequency    
    
    
    flag_dataon = true;   %debugging, initiate data connection?
    flag_stateon = true;  %debugging, execute GUI program
    flag_debugon = true;  % debugging, print debugging information
    
    replay = {};            %used for replay in debug mode
                            %format:{replay_pos,replay_buffer,data_pos,...}
    
    NKLowOffset=1024;       %data segment offset
    NKMaxSample=12000;      %number of last sample in NK buffer 
    NKRowSize=65;           %entries per NK buffer row (single sample)
    NKScaleFactor=10/75;    %scale factor of data in NKDATA
    NKMaxValue=1000;        %Y-span of EEG values (for eeg-plot)
  end
  
  %Hidden internal methods
  methods (Access = private)
    %wait for headset to connect
    function readytocollect=wait_data(this)
      fprintf('Waiting for data...\n');
      
      global NKDATA
      
      %wait for NKDATA to become not empty
      %(means c# m-driver program is online)
      %only if data is on
      tic
      while toc < this.acqTime && this.flag_dataon
        if ~isempty(NKDATA)
          readytocollect = true;
          return;
        end

        pause(1);

        if this.flag_debugon
          fprintf('Waiting for data ... \n');
        end
      end
      
      readytocollect = false;
    end

    %fake data for debugging
    function fake_data(this)
      global NKDATA
      
      %buffer length (samples)
      maxT=1000;
      
      %on first call, if replay is empty, generate replay buffer
      %of size 65xT of random data
      %format: {replay_pos,replay_buffer,data_pos}      
      if isempty(this.replay)
        this.replay={0,5*randn(this.NKRowSize,maxT),0};
      end
      
      %also create NKDATA & related if empty
      if isempty(NKDATA)
        NKDATA=randn(this.NKLowOffset+this.NKRowSize*maxT,1);
        this.replay{1}=0;
        this.replay{3}=0;

        %needs that to achieve proper offset for replays
        this.dataBuffer=this.copyNKDATA();        
        this.dataPointer=0;
        this.lastaTime=clock;  
        
        if this.flag_debugon
          fprintf('Replay: initializing NKDATA and dataBuffer for replay ***\n');
        end              
      end
      
      %also set last run time
      if isempty(this.lastTime)
        this.lastTime=clock;
        return;
      end
            
      %find out how many new samples to write to NKDATA
      c=clock;
      dt=24*3600*(datenum(c)-datenum(this.lastTime));
      T=min(maxT,round(dt*this.sampFreq));
      this.lastTime=c;
      
      %return if nothing to do
      if(T==0)
        return;
      end
      
      %reinit the replay buffer, if its size was exceeded
      if(this.replay{1}+T>size(this.replay{2},2))
        this.replay={0,5*randn(this.NKRowSize,6000),this.replay{3}};
      end
      
      %find the position of the data in replay buffer to write to NKDATA
      replay_pos=this.replay{1};
      copy_data=this.replay{2}(:,replay_pos+1:replay_pos+T);
      ncopy_data=numel(copy_data);
      
      %find the position at which to write to NKDATA
      nkdata_pos=this.replay{3};
      nkdata_idx=nkdata_pos+1:nkdata_pos+ncopy_data;
      
      %wrap the indexes around in NKDATA, if necessary
      nkdata_idx=mod(nkdata_idx-1,length(NKDATA)-this.NKLowOffset)+1;
      
      %copy replay->NKDATA
      NKDATA(nkdata_idx+this.NKLowOffset)=-copy_data(:);
      
      %simulate backoff
      if rand<0.01
        %relative backoff offsets
        backoff_idx=randi(this.NKRowSize*10,1,randi(20));
        backoff_depth=max(backoff_idx);
        
        %bring backoff idx to absolute indexes frame
        backoff_idx=nkdata_pos-backoff_idx;
        backoff_idx(backoff_idx<0)=...
          backoff_idx(backoff_idx<0)+length(NKDATA)-this.NKLowOffset;
        backoff_idx=backoff_idx + this.NKLowOffset;
        
        %write backoff data
        NKDATA(backoff_idx)=randn(size(backoff_idx));
        
        if this.flag_debugon
          fprintf('Replay: simulate backoff at position %i max depth %i num %i\n',...
            replay_pos,backoff_depth,length(backoff_idx));
        end              
      end
      
      this.replay{1}=replay_pos+T;
      this.replay{3}=nkdata_idx(end);
      
      if this.flag_debugon
        fprintf('Replay: position %i->%i:%i dt %g wrote %i samples\n',...
          replay_pos,this.replay{1},this.replay{3},dt,T);
      end      
    end    
    
    function xdata=copyNKDATA(this)
        global NKDATA
        
        xdata=-real(NKDATA);        
        xdata=xdata(this.NKLowOffset+1:end);   
        xdata=xdata*this.NKScaleFactor;
        ntuples=floor(length(xdata)/this.NKRowSize);
        ntuples=min(ntuples,this.NKMaxSample);
        xdata=xdata(1:ntuples*this.NKRowSize);
    end
    
    %get data
    function nSamplesTaken=get_data(this)        
      %on the first run of get_data (this.dataBuffer is empty),
      %copy NKDATA into dataBuffer and return
      if isempty(this.dataBuffer)
        this.dataBuffer=this.copyNKDATA();
        this.dataPointer=-1;
        this.lastaTime=clock;
        nSamplesTaken=0;
        
        if this.flag_debugon
          fprintf('NKDATA: position %i dt - read - samples\n',this.dataPointer);
        end
        
        return
      end
            
      %make a local copy of NKDATA, because NKDATA can dynamically 
      %change during execution of this function via c#mdriver
      timeCopy = toc;
      nkDataCopy = this.copyNKDATA();      
            
      %find the difference between this.databuffer and nkDataCopy
      nkDiffMap = (this.dataBuffer ~= nkDataCopy);
      
      %find first index of changed data
      idx=find(nkDiffMap);
      
      %return now if nothing was found
      if isempty(idx)
        nSamplesTaken=0;
        
        if this.flag_debugon
          fprintf('NKDATA: position %i dt - read 0 samples\n',this.dataPointer);
        end
        
        return
      end
      
      %if dataPointer is unset initial dataPointer and return (no data yet)
      if this.dataPointer<0
        this.dataPointer=floor(idx(end)/this.NKRowSize)*this.NKRowSize;
        this.dataBuffer(idx)=nkDataCopy(idx);
        nSamplesTaken=0;

        if this.flag_debugon
          fprintf('NKDATA: position %i dt - read 0 samples\n',this.dataPointer);
        end          
          
        return          
      end
      
            
      %Control for backoffs in NKDATA      
      nidx=numel(nkDiffMap);
      didx=idx-this.dataPointer;
      didx(didx<-nidx/2)=didx(didx<-nidx/2)+nidx; %wrap large negatives up
      didx(didx>nidx/2)=didx(didx>nidx/2)-nidx;   %wrap large positives down
      
      %abnormally large backoff means something broke
      if -min(didx)>this.backoffLimit*this.sampFreq*this.NKRowSize
        fprintf('NKDATA: abnormally large backoff detected(%g)\n',min(didx));        
        fprintf('NKDATA: time %g nkdata position %i dt -\n',...
          toc,this.dataPointer);
        fprintf('NKDATA: all diff indexes:\n');
        fprintf(' %g\n',idx);
                
        this.loggerState=-1;
        
        return
      end
      
      %fix reasonably small backoffs by patching dataBuffer
      if min(didx)<0
        idx=idx(didx<=0);
        
        this.dataBuffer(idx)=nkDataCopy(idx);
        nkDiffMap(idx)=0;
        
        fprintf('NKDATA: backoff detected and fixed\n');
        fprintf('NKDATA: backoff %g, patched %g entries\n',...
          min(didx),length(idx));
      end
      
      %time elapsed since last data-taking pass
      c=clock;
      dt=24*3600*(datenum(c)-datenum(this.lastaTime));
      this.lastaTime=c;      
      
      minidx=find(nkDiffMap,1,'First');      
      
      %if minidx<dataPointer, means data wrapped to the start, then
      if minidx<this.dataPointer
        %first copy everything in nkDataCopy above this.dataPointer
        output=reshape(nkDataCopy(this.dataPointer+1:end),this.NKRowSize,[]);
        this.dataBuffer(this.dataPointer+1:end)=...
                                      nkDataCopy(this.dataPointer+1:end);
        
        %then clear the upper segment of wrapped data from nkDiffMap
        nkDiffMap(this.dataPointer+1:end)=0;
        
        %reset this.dataPointer to beginning
        this.dataPointer=0;
        
        %then find the highest index of remaining changed data
        maxidx=find(nkDiffMap,1,'Last');
        
        %find the index of last changed complete 65-element-block
        maxidx=floor(maxidx/this.NKRowSize)*this.NKRowSize;
        
        %copy remaining (lower) segment of wrapped data
        output = cat(2,output,reshape(nkDataCopy(1:maxidx),this.NKRowSize,[]));
        
        %update dataPointer and dataBuffer
        this.dataBuffer(1:maxidx)=nkDataCopy(1:maxidx);        
        this.dataPointer=maxidx;
      else
        %find the highest index of changed data
        maxidx=find(nkDiffMap,1,'Last');
        
        %find index of last changed complete 65-element-block
        maxidx=floor(maxidx/this.NKRowSize)*this.NKRowSize;
        
        %copy changed data to output
        output = reshape(nkDataCopy(this.dataPointer+1:maxidx),this.NKRowSize,[]);

        %update dataPointer and dataBuffer
        this.dataBuffer(this.dataPointer+1:maxidx)=...
                                  nkDataCopy(this.dataPointer+1:maxidx);
        this.dataPointer=maxidx;
      end
            
      nSamplesTaken=size(output,2);
      this.outputMatrix(this.nS+1:this.nS+nSamplesTaken,:) = output';
      this.outputTimes(this.nS+1:this.nS+nSamplesTaken) = timeCopy;
      this.gCounter=this.gCounter+nSamplesTaken;
      
      
      %Control for taken samples count
      expectedSampleCount=ceil(dt*this.sampFreq);
      
      if nSamplesTaken>10*expectedSampleCount
        fprintf('NKDATA: exceedingly large number of samples read\n');
        fprintf('NKDATA: time %g pointer %i dt %g read %i expected %i\n',...
            toc,this.dataPointer,dt,nSamplesTaken,expectedSampleCount);
          
        fprintf('NKIUI experienced a abnormal condition\n');  
        fprintf('You can try to debug it, otherwise press F5 for abnormal finish.\n');
        
        keyboard;        
        
        this.loggerState=-2;
        
        return
      end
            
      if this.flag_debugon
        fprintf('NKDATA: position %i dt %g read %i samples (%i expected)\n',...
            this.dataPointer,dt,nSamplesTaken,expectedSampleCount);
      end
    end
    
  end
  
  %Methods accessible to experiments (descendants)
  methods (Access = protected)
    %graph EEG inputs, utility
    %ntoe: this plots to !currently! active graphic handle
    function update_eeggraph(this,channels,span,annot)
      % span is the time span to show in the graph, sec
      if nargin<3 || isempty(span)
        span=10;
      end
      
      %show legend (on/off)
      if nargin<4 || isempty(annot)
        annot=0;
      end
      
      % return immediately if there is no data
      if this.nS==0
        return;
      end
      
      % max number of labels to show in legend
      maxLabels=21;
      
      % min/max bounds on Y-axis
      maxY=this.NKMaxValue;
      
      % data channels to show in the graph
      if nargin<2 || isempty(channels)
        channels=this.DataChannels.EEGChannels;
      end
      
      %clear current axis
      cla
      
      % number of points to plot
      drawPos=min(this.gCounter);
      num=min(span*this.sampFreq,drawPos-1);
      times=(-num:-1)/this.sampFreq;
      
      
      % plot signal traces for `channels`
      plot(times,this.outputMatrix(drawPos-num+1:drawPos,channels));
      grid on
      
      % CHANGE LATER
      axis([-span 0 -maxY maxY]);
      
      if annot
        xlabel('time');
        ylabel('signal');
        nLabels=min(length(channels),maxLabels);
        legend(this.DataChannels.ChannelsHumanNames{1+...
          mod(channels(1:nLabels)-1,length(this.DataChannels.ChannelsHumanNames))},...
          'Location','EastOutside');
      end
    end
  end
  
  %Methods accessible to user
  methods (Access = public)
    function this = nklogger(acqtime,flag_dataon,flag_stateon)
      % data channels struct
      % first 21 channels in NKDATA are as in the exported NK data
      % the complete list of nonzero channels 1:30 + {31,32} active 
      % in 'Calibration' mode
      this.DataChannels = [];      
      this.DataChannels.ChannelsHumanNames = ...
        {'Fp1';'Fp2';'F3';'F4';'C3';'C4';'P3';'P4';'O1';'O2';
        'A1';'A2';'F7';'F8';'T3';'T4';'T5';'T6';'Fz';'Cz';'Pz'};
      this.DataChannels.nChannels=this.NKRowSize;
      this.DataChannels.EEGChannels = 1:21;
      this.DataChannels.nEEGChannels = 21;
      
      %this instance name
      this.name='nklogger v0';
      
      % process inits and flags
      if nargin>=1 && ~isempty(acqtime)
        this.acqTime = acqtime;
      end
      if nargin>=2 && ~isempty(flag_dataon)
        this.flag_dataon = flag_dataon;
      end
      if nargin>=3 && ~isempty(flag_stateon)
        this.flag_stateon = flag_stateon;
      end
    end
    
    function o = run(this)      
      %% Initialization
      global NKDATA
      NKDATA=[];
      
      %WAIT for data source
      if this.flag_dataon        
        readyToCollect = this.wait_data();
        
        %if data source is not ready, exit here
        if ~readyToCollect          
          fprintf('Expired while waiting for devices, quiting...\n');
          return;
        end
      end
            
      %initialize acquisition dataset
      %this is the run's unique alphanumeric ID
      this.idtag=[datestr(now,'yyyymmddHHMM') '.' ...
                              dec2hex(randi(intmax('uint32'),'uint32'))];
      fprintf('This UID is %s...\n',this.idtag);
      
      %trigger record array
      this.marker = zeros(ceil((this.acqTime+60)*this.sampFreq),1);
      %data matrix, time x channels
      this.outputMatrix = zeros(ceil((this.acqTime+60)*this.sampFreq),...
                                             this.DataChannels.nChannels);
      
      %HOOK this.prepare_disp 
      %[initialize GUI]
      this.prepare_disp();
      
      
      %% DATA COLLECTION loop
      fprintf('Starting session, press ''q'' to quit...\n');
      
      this.nS = 0;
      this.loggerState=0;
      this.gCounter=zeros(1,1);
      this.lastTime=clock;
      this.lastaTime=clock;
      this.dataBuffer=[];
      this.effectiveFreq=this.sampFreq;
      this.freqTracking=[0 0 0 0 0];
      effFreq=this.effectiveFreq;
      effOffset=0;      

      %debug timing data
      ttime=zeros(1,8);   
      dbgdatacnt=1;
      this.dbgdata=zeros(10000,8);      
      
      tic
      while toc<this.acqTime
        this.curTime=toc;        
        
        ttime(1)=this.curTime;
        
        %HOOK [update GUI & state variables]        
        %this.preupdate_state
        if this.flag_stateon
          this.preupdate_state(toc);
        end        
        
        %user termination
        key=get(gcf,'CurrentCharacter');     
        if strcmp(key,'Q') || strcmp(key,'q')
          break;
        end
        
        ttime(2)=toc;
        
        %if flag_dataon==false, produce fake data now
        if ~this.flag_dataon
          this.fake_data();
        end
        
        %effective frequency tracking, time
        tt=toc;
        
        %[IMPORTANT]get data from data source
        this.get_data();
                        
        ttime(3)=toc;
        
        %HOOK [update GUI & state variables] 
        %this.update_state
        if this.flag_stateon
          this.update_state(toc);
        end
        
        %attempt this to fix up clock lagging behind GUI
        pause(0.001);
        
        ttime(4)=toc;
        
        %update number of samples counter
        this.nS=min(this.gCounter);
        nn=this.nS;
        
        %control for number of samples vs wall clock
        expectedSamples=round(tt*effFreq+effOffset);        
        if abs(expectedSamples-this.nS)>this.clockDiscrepancyLimit*effFreq
          fprintf('MAIN: number of samples and clock diverged\n');
          fprintf('MAIN: time %g samples %g, expected %g\n',...
            toc,this.nS,expectedSamples);
          this.loggerState=-3;
        end        
        
        if this.flag_debugon
          fprintf('MAIN: time %g samples %g (%g expected)\n',...
            toc,this.nS,expectedSamples);
        end

        %update linear fit for number of samples
        if nn>0
            this.freqTracking=this.freqTracking+[tt*nn,tt^2,nn,tt,1];
            if this.freqTracking(5)>1
                efs=this.freqTracking/this.freqTracking(end);
                effFreq=(efs(1)-efs(3)*efs(4))/(efs(2)-efs(4)^2);
                effOffset=efs(3)-efs(4)*effFreq;
                this.effectiveFreq=effFreq;
            
                if this.flag_debugon
                  %fprintf('MAIN: effs %g %g %g %g %i\n',this.freqTracking);
                  fprintf('FREQ: eff freq %g eff offset %g\n',effFreq,effOffset);
                end            
            end
        end                
        
        ttime(5)=toc;
        
        %calculate the time to wait until next loop pass
        %loop passes once per 100 msec
        %(0.01 added to avoid rounding problems)
        pauseTime=ceil((toc+0.01)*10)/10-toc;
        
        ttime(6)=toc;
        
        if (toc-this.curTime<0.1)        
          pause(pauseTime);
        else
          pauseTime=0;
        end
        
        ttime(7)=toc;        
        ttime(8)=pauseTime;
        
        %store timing debug data
        if dbgdatacnt>size(this.dbgdata,1)
          this.dbgdata=cat(1,this.dbgdata,zeros(10000,8));
        end          
        this.dbgdata(dbgdatacnt,:)=ttime;
        dbgdatacnt=dbgdatacnt+1;
        
        %control for emergency exit states
        if this.loggerState<0
          fprintf('MAIN: an exceptional state detected\n');
          fprintf('MAIN: terminating with status %g\n',this.loggerState);
          break
        end
      end
      
      
      fprintf('Session ended, cleaning up...\n');
      
      this.dbgdata=this.dbgdata(1:dbgdatacnt-1,:);      
      
      %HOOK this.finalize_disp 
      %[finalize GUI]
      this.finalize_disp();      
      
      % write "out" the data
      o=this.getData();
      
      %save data
      fname=sprintf('nkiui%s-o.mat',this.idtag);
      save(fname,'o');      
    end
    
    function out = getData(this)
      % write out the data
      n=this.nS;                  %total samples
      out=struct('id',this.idtag,'tag','','nS',n,'sampFreq',this.sampFreq,...
        'marker',this.marker(1:n),'data',this.outputMatrix(1:n,:),...
        'chnames',[],'binsuV',1);
      out.chnames=this.DataChannels.ChannelsHumanNames;
    end
        
    %HOOK: this.prepare_disp
    %[prepare GUI]
    %This function is responsible for initializing GUI according
    %to experiment's design. GUI is a graphical form used to
    %communicate to user the experiment program and any other
    %information. Experiment designer is responsible for writing 
    %this function. This function is called after connection to 
    %data source right before data-acquisition loop is started.
    %Example below will create one Matlab figure for GUI.
    function prepare_disp(this)
      if(this.fig == 0)
        this.fig = figure;
      end
      
      figure(this.fig),clf,set(this.fig, 'menubar', 'none');
    end
    
    %HOOK: this.finalize_disp
    %[finalize GUI]
    %This function is responsible for closing GUI according
    %to experiment's design. Experiment designer is responsible 
    %for writing this function. This function is called after 
    %the data acquisition loop concluded.
    function finalize_disp(this)

    end    
    
    %HOOK: this.preupdate_state
    %[update GUI and state variables, pre]
    %This function is responsible for updating GUI according
    %to experiment program and doing any other actions to record
    %experiment's trigger program. This function maintains this.marker
    %array of the experiment's trigger record. Experiment designer is
    %responsible for writing this function. This function is called 
    %at each data-acquisition cycle BEFORE new data bactch had been 
    %acquired.
    function preupdate_state(this,curr_time)
      
    end        
    
    %HOOK: this.update_state
    %[update GUI and state variables, post]
    %This function is responsible for updating GUI according
    %to experiment program and doing any other actions to record
    %experiment's trigger program. This function maintains this.marker
    %array of the experiment's trigger record. Experiment designer is
    %responsible for writing this function. This function is called 
    %at each data-acquisition cycle AFTER new data bactch had been 
    %acquired.
    %Example below will draw EEG graphs in GUI figure.
    function update_state(this,curr_time)
      figure(this.fig), hold on      
      this.update_eeggraph(this.DataChannels.EEGChannels,[],1);
      this.marker(this.nS+1:min(this.gCounter))=this.curTime;
    end    
  end
    
end
