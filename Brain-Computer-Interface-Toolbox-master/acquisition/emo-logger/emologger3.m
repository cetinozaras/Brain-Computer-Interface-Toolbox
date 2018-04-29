classdef emologger3 < handle
  % EMOTIV EEG data acquisition base class.
  %
  % Usage:
  % emo=emologger3(acqusition_time_in_seconds);
  % o=emo.run
  %
  % Change history:
  %  v1 - initial code
  %  v2 - adds support for multiple EMOTIV headsets, performance tweaks
  %  v3 - removes support for 'trials' field
  %
  %################## IMPORTANT NOTE #############################
  %This program should be used with 32bit Matlab versions since EMOTIV dll
  %libraries, used to connect to the EMOTIV headests, are 32 bit and, thus,
  %cannot be loaded by 64bit Matlab
  %################## IMPORTANT NOTE #############################
  %
  % Y.Mishchenko (c) 2015

 
  % +++ some extra dll-interface functions, for reference
  % unloadlibrary('edk'); % unload the library after having turned off
  % [int32, uint32Ptr] EE_DataGetSamplingRate (uint32, uint32Ptr)
  % int32 EE_DataSetSychronizationSignal (uint32, int32)
  % [int32, string] EE_EnableDiagnostics (cstring, int32, int32)
  
  %Hidden properties
  properties (Access = private)
    hData = 0;        %emoEngine data handle
    eEvent = 0;       %emoEngine event handle
    gCounter=[];      %global sample counter, per device
    baseEEGChannels   %original EMOTIV EEG channel ids
  end
  
  %Hidden properties accessible to experiment implementations
  properties (Access = protected)
    %connected user ids and the number of connected users
    userIDs=[];               %array of connected user IDs
    nUsers=0;                 %number of connected users
    
    %variables used to manage experiment's UI
    cueState                  %current UI state
    cueLength = 1;            %UI time step
    program = zeros(1,1000);  %UI program
    lastTime = [];            %last data-acquisition loop's run
  end
  
  %Read-only public properties accessible to user
  properties(GetAccess = public, SetAccess = protected)
    name              %This object instance's name
    sampFreq = 128;   %sampling frequency    
  end
  
  %Read-only public properties accessible to user
  properties (GetAccess = public, SetAccess = private)
    structs           %EMOTIV headset data
    enuminfo          %EMOTIV data channels
    DataChannels      %EMOTIV data channels
    nChannels         %EMOTIV data channels, count
    EEGChannels       %EEG data channel ids in `data`
    nEEGChannels      %EEG data channels count in `data`
    
    idtag             %experiment's unique alpha-numeric ID
    markers           %experiment's array of cue-labels
    outputMatrix      %experiment's data
    timeStamps        %samples' timestamps
    nS                %total samples count
    
    dbgdata           %debug data
  end
  
  %Read-write public properties accessible to user
  properties  (Access = public)
    bufSize = 1;      %size of EMOTIV data buffer, sec
    acqTime = 60;     %total/max acqusition time, sec
    fig = 1;          %figure number used for experiment's UI
    
    flag_dataon = true;     %debugging, initiate data connection to headset?
    flag_stateon = true;    %debugging, play experiment's UI program
    flag_debugon = false;   %debugging, print debugging information
  end
    
  %Hidden internal methods
  methods (Access = private)
    
    %connect to emoEngine
    function AllOK=connect(this)
      % check to see if dll library was already loaded or load the dll
      if ~libisloaded('edk')
        [nf, w] = loadlibrary('edk','edk');
        disp('############### EDK library loaded');
        if this.flag_debugon
          %debug, library info
          libfunctionsview('edk')
          
          %debug, these should be empty if all went well
          disp(nf);
          disp(w);
        end
      else
        disp('EDK library already loaded');
      end
      
      % establish communication with the engine
      default = int8(['Emotiv Systems-5' 0]);
      AllOK = calllib('edk','EE_EngineConnect',default); % success means this is 0
      
      fprintf('EmoEngine connected with answer %i\n',AllOK);
      
      % create handles to support communication with the engine
      calllib('edk','EE_DataSetBufferSizeInSec',this.bufSize);      
      this.hData = calllib('edk','EE_DataCreate');
      this.eEvent = calllib('edk','EE_EmoEngineEventCreate');
      
      % query sampling rate
      sampRateOutPtr = libpointer('uint32Ptr',0);
      calllib('edk','EE_DataGetSamplingRate',0,sampRateOutPtr);
      this.sampFreq = get(sampRateOutPtr,'value'); % in Hz      
    end
    
    %release emoEngine
    function close(this)
      calllib('edk','EE_EmoEngineEventFree',this.eEvent);
      calllib('edk','EE_DataFree',this.hData);
      calllib('edk','EE_EngineDisconnect');
      disp('EmoEngine released, shutting down...');
    end
    
    %wait for headset to connect
    function readytocollect=wait_data(this)
      fprintf('Waiting for devices...\n');
      
      %NOTE
      % EE_UserAdded are the first events in emotiv's events stack;
      % therefore, get all EE_UserAdded events and quit
      tic
      while toc < this.acqTime
        %query EMOTIV events, state = 0 if everything is OK
        state = calllib('edk','EE_EngineGetNextEvent',this.eEvent);
        if state ~= 0
          pause(0.1);
          continue; 
        end
        
        eventType = calllib('edk','EE_EmoEngineEventGetType',this.eEvent);
        
        if this.flag_debugon
          fprintf('Caught event:%s\n',eventType);
        end
        
        userID=libpointer('uint32Ptr',0);
        calllib('edk','EE_EmoEngineEventGetUserId',this.eEvent, userID);
        userID_value = get(userID,'value');
        
        if strcmp(eventType,'EE_UserAdded') == true
          this.userIDs=union(this.userIDs,userID_value);
          calllib('edk','EE_DataAcquisitionEnable',userID_value,true);
          fprintf('Device %i connected\n',userID_value);
        else
          break;
        end
      end
            
      %ready to collect if there are connected users      
      readytocollect = ~isempty(this.userIDs);
      this.nUsers=length(this.userIDs);
      fprintf('Total devices connected %i\n',this.nUsers);
    end
    
    %get data from headset (24 channels x up-to-buffer-length)
    %samples are placed into output matrix based on ED_timestamp & ED_counter
    function nS=get_data(this)
      %sync/flash output datastream if first time
      if isempty(this.gCounter)
        for uid=1:this.nUsers
          calllib('edk','EE_DataUpdateHandle', this.userIDs(uid), this.hData);
        end
        this.gCounter=zeros(1,this.nUsers);
      end
      
      
      nS=0;
      numChannels=length(fieldnames(this.enuminfo.EE_DataChannels_enum));
      for uid=1:this.nUsers
        %get data into buffer for user this.userIDs(uid)
        calllib('edk','EE_DataUpdateHandle', this.userIDs(uid), this.hData);
        nSamples = libpointer('uint32Ptr',0);
        calllib('edk','EE_DataGetNumberOfSample',this.hData,nSamples);
        nSamplesTaken = get(nSamples,'value') ;        
        nS=max(nS,nSamplesTaken);
        
        if nSamplesTaken > 0
          %extract the data from buffer
          output=zeros(nSamplesTaken,numChannels);
          data = libpointer('doublePtr',zeros(1,nSamplesTaken));
          for k = 1:numChannels
            calllib('edk','EE_DataGet',this.hData, this.DataChannels.([this.DataChannels.ChannelsNames{k}]), data, uint32(nSamplesTaken));
            output(1:nSamplesTaken,k) = get(data,'value');
          end
          
          %insert data into 'output' ~~NOTE NO CONTROL OVER CONTINUITY!~~
          gRange=(1:numChannels)+(uid-1)*numChannels;
          this.outputMatrix(this.gCounter(uid)+1:this.gCounter(uid)+nSamplesTaken,gRange) = output;
          this.gCounter(uid)=this.gCounter(uid)+nSamplesTaken;
        end
      end
      
      if this.flag_debugon
        fprintf('Received total %i samples\n',nS);
      end
    end
    
  end
  
  %Methods accessible to experiments (descendants)
  methods (Access = protected)  
    %graph EEG inputs, utility 
    %ntoe: this plots to !currently! active graphic handle
    function update_eeggraph(this,channels,span,annot)
      % span is the time span to show in the graph, sec
      if(nargin<3 || isempty(span))
        span=10;
      end
      
      if(nargin<4 || isempty(annot))
        annot=0;
      end
      
      % don't do this if there is no data
      if(this.nS==0)
        return;
      end
      
      % max number of labels to show in legend
      maxLabels=14;
      
      % data channels to show in the graph
      if(nargin<2 || isempty(channels))
        channels=this.EEGChannels;
      end
      
      %clear current axis
      cla
      
      colors={'b--';'g--';'r--';'c--';'m--';'y--';'k--';
        'b-.';'g-.';'r-.';'c-.';'m-.';'y-.';'k-.';
        'b:';'g:';'r:';'c:';'m:';'y:';'k:',
        'b-';'g-';'r-';'c-';'m-';'y-';'k-';};
      
      % number of points to plot
      num=min(span*this.sampFreq,this.nS-1);
      times=(-num:-1)/this.sampFreq;
      
      
      % plot signal traces for `channels`
      for k = 1:length(channels)
        ik=mod(k,length(colors))+1;   %(cycle through `colors`)
        plot(times,this.outputMatrix(this.nS-num+1:this.nS,channels(k)),colors{ik});
      end
      
      axis([-span 0 3000 6000]);
      
      if(annot)
        xlabel('time');
        ylabel('signal');
        nLabels=min(length(channels),maxLabels);
        legend(this.DataChannels.ChannelsHumanNames{1+...
          mod(channels(1:nLabels)-1,length(this.DataChannels.ChannelsHumanNames))},...
          'Location','West');
      end
    end
  end
  
  %Methods accessible to user
  methods (Access = public)
    function this = emologger2(acqtime,flag_dataon,flag_stateon,bufsize)
      % data structures, copied and pasted from epocmfile.m
      this.structs.InputSensorDescriptor_struct.members=struct('channelId', 'EE_InputChannels_enum', 'fExists', 'int32', 'pszLabel', 'cstring', 'xLoc', 'double', 'yLoc', 'double', 'zLoc', 'double');
      this.enuminfo.EE_DataChannels_enum=struct('ED_COUNTER',0,'ED_INTERPOLATED',1,'ED_RAW_CQ',2,'ED_AF3',3,'ED_F7',4,'ED_F3',5,'ED_FC5',6,'ED_T7',7,'ED_P7',8,'ED_O1',9,'ED_O2',10,'ED_P8',11,'ED_T8',12,'ED_FC6',13,'ED_F4',14,'ED_F8',15,'ED_AF4',16,'ED_GYROX',17,'ED_GYROY',18,'ED_TIMESTAMP',19,'ED_ES_TIMESTAMP',20,'ED_FUNC_ID',21,'ED_FUNC_VALUE',22,'ED_MARKER',23,'ED_SYNC_SIGNAL',24);
      this.enuminfo.EE_CognitivTrainingControl_enum=struct('COG_NONE',0,'COG_START',1,'COG_ACCEPT',2,'COG_REJECT',3,'COG_ERASE',4,'COG_RESET',5);
      this.enuminfo.EE_ExpressivAlgo_enum=struct('EXP_NEUTRAL',1,'EXP_BLINK',2,'EXP_WINK_LEFT',4,'EXP_WINK_RIGHT',8,'EXP_HORIEYE',16,'EXP_EYEBROW',32,'EXP_FURROW',64,'EXP_SMILE',128,'EXP_CLENCH',256,'EXP_LAUGH',512,'EXP_SMIRK_LEFT',1024,'EXP_SMIRK_RIGHT',2048);
      this.enuminfo.EE_ExpressivTrainingControl_enum=struct('EXP_NONE',0,'EXP_START',1,'EXP_ACCEPT',2,'EXP_REJECT',3,'EXP_ERASE',4,'EXP_RESET',5);
      this.enuminfo.EE_ExpressivThreshold_enum=struct('EXP_SENSITIVITY',0);
      this.enuminfo.EE_CognitivEvent_enum=struct('EE_CognitivNoEvent',0,'EE_CognitivTrainingStarted',1,'EE_CognitivTrainingSucceeded',2,'EE_CognitivTrainingFailed',3,'EE_CognitivTrainingCompleted',4,'EE_CognitivTrainingDataErased',5,'EE_CognitivTrainingRejected',6,'EE_CognitivTrainingReset',7,'EE_CognitivAutoSamplingNeutralCompleted',8,'EE_CognitivSignatureUpdated',9);
      this.enuminfo.EE_EmotivSuite_enum=struct('EE_EXPRESSIV',0,'EE_AFFECTIV',1,'EE_COGNITIV',2);
      this.enuminfo.EE_ExpressivEvent_enum=struct('EE_ExpressivNoEvent',0,'EE_ExpressivTrainingStarted',1,'EE_ExpressivTrainingSucceeded',2,'EE_ExpressivTrainingFailed',3,'EE_ExpressivTrainingCompleted',4,'EE_ExpressivTrainingDataErased',5,'EE_ExpressivTrainingRejected',6,'EE_ExpressivTrainingReset',7);
      this.enuminfo.EE_CognitivAction_enum=struct('COG_NEUTRAL',1,'COG_PUSH',2,'COG_PULL',4,'COG_LIFT',8,'COG_DROP',16,'COG_LEFT',32,'COG_RIGHT',64,'COG_ROTATE_LEFT',128,'COG_ROTATE_RIGHT',256,'COG_ROTATE_CLOCKWISE',512,'COG_ROTATE_COUNTER_CLOCKWISE',1024,'COG_ROTATE_FORWARDS',2048,'COG_ROTATE_REVERSE',4096,'COG_DISAPPEAR',8192);
      this.enuminfo.EE_InputChannels_enum=struct('EE_CHAN_CMS',0,'EE_CHAN_DRL',1,'EE_CHAN_FP1',2,'EE_CHAN_AF3',3,'EE_CHAN_F7',4,'EE_CHAN_F3',5,'EE_CHAN_FC5',6,'EE_CHAN_T7',7,'EE_CHAN_P7',8,'EE_CHAN_O1',9,'EE_CHAN_O2',10,'EE_CHAN_P8',11,'EE_CHAN_T8',12,'EE_CHAN_FC6',13,'EE_CHAN_F4',14,'EE_CHAN_F8',15,'EE_CHAN_AF4',16,'EE_CHAN_FP2',17);
      this.enuminfo.EE_ExpressivSignature_enum=struct('EXP_SIG_UNIVERSAL',0,'EXP_SIG_TRAINED',1);
      this.enuminfo.EE_Event_enum=struct('EE_UnknownEvent',0,'EE_EmulatorError',1,'EE_ReservedEvent',2,'EE_UserAdded',16,'EE_UserRemoved',32,'EE_EmoStateUpdated',64,'EE_ProfileEvent',128,'EE_CognitivEvent',256,'EE_ExpressivEvent',512,'EE_InternalStateChanged',1024,'EE_AllEvent',2032);
      
      this.DataChannels = this.enuminfo.EE_DataChannels_enum;
      this.DataChannels.ChannelsNames = {'ED_COUNTER','ED_INTERPOLATED','ED_RAW_CQ','ED_AF3','ED_F7','ED_F3','ED_FC5','ED_T7','ED_P7','ED_O1','ED_O2','ED_P8','ED_T8','ED_FC6','ED_F4','ED_F8','ED_AF4','ED_GYROX','ED_GYROY','ED_TIMESTAMP','ED_ES_TIMESTAMP','ED_FUNC_ID','ED_FUNC_VALUE','ED_MARKER','ED_SYNC_SIGNAL'};
      this.DataChannels.ChannelsHumanNames = {'COUNTER','INTERPOLATED','RAW_CQ','AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4','GYROX','GYROY','TIMESTAMP','ES_TIMESTAMP','FUNC_ID','FUNC_VALUE','MARKER','SYNC_SIGNAL'};
      this.DataChannels.ChannelsModifiedNames = {};
      this.nChannels=length(this.DataChannels.ChannelsNames);
      
      this.EEGChannels = 4:17;
      this.baseEEGChannels = 4:17;
      this.nEEGChannels=length(this.EEGChannels);
      
      this.name='Emologger v2';
      
      % experiment related initializations
      if(nargin>=1 && ~isempty(acqtime))
        this.acqTime = acqtime;
      end
      if(nargin>=2 && ~isempty(flag_dataon))
        this.flag_dataon = flag_dataon;
      end
      if(nargin>=3 && ~isempty(flag_stateon))
        this.flag_stateon = flag_stateon;
      end
      if(nargin>=4 && ~isempty(bufsize))
        this.bufSize = bufsize;
      end
      
    end
    
    function out = run(this)  
      this.dbgdata=[];
      
      if(this.flag_dataon)
        %CONNECT to emotiv headset (this uses emotiv dll library)
        AllOK=this.connect();
        if(AllOK~=0)
          fprintf('Error connecting to EmoEngine, quiting...\n');
          return;
        end
        
        %WAIT for users to connect
        readyToCollect = this.wait_data();
        
        if ~readyToCollect
          %if device is not ready exit here
          fprintf('Expired while waiting for devices, quiting...\n');
          this.close();
          return;
        else
          %depending on the number of devices, update this.EEGChannels
          channels=[];
          numChannels=length(fieldnames(this.enuminfo.EE_DataChannels_enum));
          for i=0:this.nUsers-1
            channels=union(channels,this.baseEEGChannels+i*numChannels);
          end
          this.EEGChannels=channels;
          this.nEEGChannels=length(channels);
        end
      else
        this.nUsers=1;
        this.lastTime=[];
      end
      
      %uiprogram-hook, initialize UI program
      this.prepare_prg();
      
      %initialize acquisition datasets
      %this run's unique alphanumeric ID
      this.idtag=[datestr(now,'yyyymmddHHMM') '.' dec2hex(randi(intmax('uint32'),'uint32'))];
      fprintf('This UID is %s...\n',this.idtag);
      
      %UI program
      this.markers = zeros((this.acqTime+1)*this.sampFreq,1);
      %acqusition timestamps as [year month day hour min sec.msec]
      this.timeStamps = zeros((this.acqTime+1)*this.sampFreq,6);
      %data's matrix time x nUsers*nDataChannels
      this.outputMatrix = zeros((this.acqTime+1)*this.sampFreq,this.nUsers*this.nChannels);
      this.nS=0;

      
      %uiinit hook, initialize GUI
      this.prepare_disp();
      
            
      %DATA COLLECTION loop
      fprintf('Starting session, press ''q'' to quit...\n');
      
      this.nS = 0;
      this.cueState=0;
      this.gCounter=[];
      
      tic
      while toc < this.acqTime
        ttime=zeros(1,5);
        ttime(1)=toc;
        
        key=get(gcf,'CurrentCharacter');
        if(strcmp(key,'Q') || strcmp(key,'q'))  %quit and terminate
          break;
        end
                
        ttime(2)=toc;        
        if this.flag_dataon
          %get data for device runs
          this.get_data();
          
          %add ui-program and timestamps data
          if(~isempty(this.gCounter))
            T=min(this.gCounter)-this.nS;
            this.markers(this.nS+1:this.nS+T) = this.cueState;
            this.timeStamps(this.nS+1:this.nS+T,:)=repmat(clock,[T, 1]);
            this.nS = this.nS + T;
          end          
        else
          %faking data for debug, no-device runs
          if(isempty(this.lastTime))
            this.lastTime=clock;
            T=round(this.sampFreq*this.bufSize);
          else
            c=clock;
            dt=24*3600*(datenum(c)-datenum(this.lastTime));
            T=round(dt*this.sampFreq);
            this.lastTime=c;
          end

          this.outputMatrix(this.nS+1:this.nS+T,:) = 4500;
          
          this.markers(this.nS+1:this.nS+T) = this.cueState;
          this.timeStamps(this.nS+1:this.nS+T,:)=repmat(clock,[T, 1]);          
          this.nS = this.nS + T;                    
        end
        
        ttime(3)=toc;
        
        % update UI
        if this.flag_stateon
          pos=mod(ceil(toc/this.cueLength),length(this.program))+1;
          this.cueState=this.program(pos);
          
          %ui-update hook, update UI
          this.update_state(this.cueState);
        end
        
        ttime(4)=toc;  
        
        %calculate the time to wait for the next loop pass
        pauseTime=ceil(toc*10+0.01)/10-toc;
        pause(pauseTime);
        
        ttime(5)=pauseTime;
        
        %debug timing data
        this.dbgdata=cat(1,this.dbgdata,ttime);
      end
      
      fprintf('Session ended, cleaning up...\n');
      
      if(this.flag_dataon)
        this.close();
      end
      
      % write out the data
      n=this.nS;                  %total samples
      out=struct('id',this.idtag,'tag','','nS',n,'sampFreq',this.sampFreq,...
        'marker',this.markers(1:n),'timestamp',this.timeStamps(1:n,:),...
        'data',this.outputMatrix(1:n,:),'nTrials',this.trialsCounter,...
        'trials',this.trialsMatrix);
    end
    
    function out = getData(this)
      % write out the data
      n=this.nS;                  %total samples      
      out=struct('id',this.idtag,'tag','','nS',n,'sampFreq',this.sampFreq,...
        'marker',this.markers(1:n),'timestamp',this.timeStamps(1:n,:),...
        'data',this.outputMatrix(1:n,:),'nTrials',this.trialsCounter,...
        'trials',this.trialsMatrix);
    end
  end
  
  
  %THESE FUNCTIONS (HOOKS) NEED TO BE OVERWRITTEN BY UI IMPLEMENTATION
  methods (Access = protected)    
    %HOOK: prepare UI program
    %this function is responsible for initializing UI cue program
    %according to the experiment's design, UI cue program is an
    %array of states controling the visual cues communicated by
    %the computer to the operator during experiment, each element
    %in the array defines a presentation of one cue of time
    %cueLength seconds; experiment designer is responsible for
    %writing this function, this function should prepare and
    %store the program array in "this.program" variable
    function prepare_prg(this)
      this.program=zeros(1,10000);
      this.program(1)=1;
    end
    
    %HOOK: prepare UI
    %this function is responsible for initializing cue UI according
    %to the experiment's design, cue UI is graphical form used to
    %communicate to user the experiment's program and any other
    %necessary information; experiment designer is responsible
    %for writing this function.
    %this function is called after connection to EMOTIV headset
    %had been established and data acquisition handle acquired
    function prepare_disp(this)
      %this sample hook will create single figure
      
      if(this.fig == 0)
        this.fig = figure;
      end
      
      figure(this.fig),clf,set(this.fig, 'menubar', 'none');
    end
    
    %HOOK: update UI
    %this function is responsible for updating cue UI according
    %to the experiment's program; experiment's designer is
    %responsible for writing this function
    %this function is called at each new data-acquisition cycle
    %after acquiring new data bactch and before updating trials
    function update_state(this,cuestate,info)
      %this sample hook will update eeg graphs
      
      figure(this.fig), hold on
      
      this.update_eeggraph(this.EEGChannels,[],1);
    end
  end
  
end
