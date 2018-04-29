classdef nkiui2 < nkiui
  % Nihon Kohden Interactive User Interface class, version 2 - 3 state
  % control model. The control model: 
  % - Left/Right to advance left/right or forward/backward
  % - Neutr to switch modes left/right <-> forward/backward
  %
  % Usage:
  % [TO CREATE INSTANCE]
  % nk=nkiui2(duration);
  %
  % [TO REPLAY DATA]
  % nk.replay=replay; nk.program=program;
  % `replay` sould be cell-array of the form {0,eegdata,0};
  %  eegdata should be 65xT matrix, if using nkimport o.data, do 
  % replay={0,[o.data';zeros(43,o.nS)],0};
  %
  % [TO GENERATE EXPERIMENT PROGRAM]
  % nk.prepare_prg(design);
  %  design is a string like 'SBIBS':
  %  S - standard cued session;
  %  I - free interactive session
  %  B - break
  %
  % [TO ADJUST BCI-DETECTOR PARAMETERS]
  % TODO
  %
  % [IF PRETRAINING EXAMPLES AVAILABLE (data, labels)]
  % nk.pretrain_examples(data,labels);
  %
  % [TO RUN]
  % o=nk.run
  %
  % [TO GET DATA, POST-RUN]
  % o=nk.getData();
  %
  % PUBLIC VARIABLES
  %  fig_ipos - initial size+position of the figure, eg [527 56 836 616]
  %     
  %  PROGRAM SECTION
  %  maxcue   - number of cues to use, eg 6
  %  twait    - initial relaxation wait time, sec, eg 120
  %  break_time  - length of in-between sessions breaks, sec, eg 120  
  %  trial_num   - trials per session, eg 300 
  %  flag_animon - use robot animation
  %  flag_mcmatrixon - use detection matrix animation
  %  flag_fbindicatoron - use detection indicator animation
  %  train_delay - set delay before starting detector training, trials
  %  train_period- set period for re-training detector, trials
  %
  %  program     - trigger program, can manually specify if needed
  %     
  %  DETECTOR CONFIG
  %  dt1         - epoch start (pre-trigger, sec), eg 0
  %  dt2         - epoch end (post-trigger, sec), eg 0.85
  %  targets     - detection targets, arrange in the order of priority, 
  %                highest priority-first; this is effective in detection  
  %                in cases of detector ties, eg [3 1 2 6 4 5]
  %  chidx       - valid data channels positions, eg 1:21
  %  sets        - bisection sets, manually specify if needed, 
  %                eg {[1 2],[1 3],[2 3]}
  %  ftidx       - ft-feature selector, manually specify if needed       
  %  examples    - exampels of event features, manually provide 
  %                pretraining examples if needed
  %  labels      - labels of events in examples, manually provide
  %                if neeeded
  %  nexamples   - number of examples, adjust if manually provided examples
  %  ispretrained- set to true if manually providing pretraining examples
  %
  % To automatically create examples, labels and nexamples variables and 
  % pretrain detector before nk.run, do nk.pretrain_examples(data,marker). 
  % Here data={eegdata{1},eegdata{2},...}, is a cell array of EEG data 
  % records to be used to extract examples, and marker={marker{1},
  % marker{2},...} is a cell array of corresponding examples' labels.
  %
  % Change history:
  % v1.0 2016-08-17 complete
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
  end
  
  %Hidden properties accessible to experiment implementations
  properties (Access = protected)
    ccmode=0;       %advancement mode 0|1
    hhmode=0;       %advancement mode indicator
  end
  
  %Read-only public properties accessible to user
  properties(GetAccess = public, SetAccess = protected)
  end
  
  %Read-only public properties accessible to user
  properties (GetAccess = public, SetAccess = private)    
  end
  
  %Read-write public properties accessible to user
  properties  (Access = public)    
  end
  
  %Hidden internal methods
  methods (Access = protected)
    %collect examples of events in feature space
    function collect_examples(this)
      timein=toc;
      
      dt1=this.dt1;       %epoch start (pre-trigger, sec)
      dt2=this.dt2;       %epoch end (post-trigger, sec)
      chidx=this.chidx;   %valid data channels
      targets=this.targets;   %all target events
      targets(end+1)=this.interactive_cue;  %interactive event
      nch=length(chidx);     %number of data channels
      
      %get the fragment of data not yer processed
      curr_pos=max(this.gCounter);
      marker=this.marker(this.last_example+1:curr_pos);
      
      %construct new epochs
      dt=ceil(this.sampFreq*(dt1+dt2)); %total epoch length, samples
      ddt=ceil(this.sampFreq*dt2);      %epoch length after trigger
      
      %construct epoch-on markers
      idx=find(diff(marker)>0);     %stimulus on-edge
      idxon=idx(1:end)+ddt;
      xidx=idxon;
      
      markers=marker(xidx-ddt+1);   %epochs' trigger values
      
      %keep only events within 'targets'
      idx=1:length(xidx);
      idx=idx(ismember(markers,targets));
      
      %restrict offsets to only those in idx
      xidx=xidx(idx);
      markers=markers(idx);      
      
      %make offsets for this.outputMatrix
      xidx=this.last_example+xidx;
      
      if this.flag_debugon
          fprintf('Examples: found %i examples of events ',length(xidx));
          fprintf(' %i @ %i ',[markers,xidx]');      
          fprintf('\n');
      end
      
      
      %CORRECT FOR NK NONUNIFORM/DELAYED DATA STREAM
      %adjust epoch-on position based on trigger channel, if available
      if ~isempty(this.serial1) || (~this.flag_dataon && this.triggerch>0)
        for i=1:length(idx)
          tp=xidx(i)-dt;
          t0=tp-ceil(0.1*this.sampFreq);
          t1=tp+ceil(this.triggerdt*this.sampFreq);
          
          trigger_fragment=this.outputMatrix(t0+1:t1,this.triggerch);
          
          idxprop=find(trigger_fragment>...
            this.triggerthresh*this.NKScaleFactor,1,'First');
          
          if ~isempty(idxprop)
            if this.flag_debugon
              fprintf('Examples: found tt-correction for %i: +%i\n',...
                xidx(i),idxprop-ceil(0.1*this.sampFreq));
            end
            
            xidx(i)=t0+idxprop+dt-1;
          end
        end
        
        %check if any event got deferred (the end is not included 
        %in the current dataset)
        xidx_deferred=xidx(xidx>curr_pos);
        if ~isempty(xidx_deferred) && this.flag_debugon
          fprintf('Examples: deferred ');
          fprintf(' %i ',xidx_deferred);
          fprintf('\n');
        end
        
        %all the rest can be processed
        markers=markers(xidx<=curr_pos);
        xidx=xidx(xidx<=curr_pos);
      end
      
      %add new examples only if idx is not empty
      if ~isempty(xidx)
        nn=length(xidx);
        
        if this.flag_debugon
          fprintf('Examples: adding %i new examples ',nn);
        end
        
        examples=zeros(nn,dt,nch);
        for k=1:nn
          tp=xidx(k);        %kth epoch end point
          examples(k,:,:)=this.outputMatrix(tp-dt+1:tp,chidx);
          this.amarker(tp-dt+1:tp)=markers(k);
        end
        
        %DEBUG
        dbgexamples=examples;
        %DEBUG
        
        %ns number of samples in one example == (dt1+dt2)*sampFreq
        ns=size(examples,2);
        
        %calculate FT features, (keep 2:maxFreq+1)
        examples=fft(examples,[],2)/(this.sampFreq/200);
        maxFreq=floor((ns-1)/2);
        examples=examples(:,2:1+maxFreq,:);
        
        nn=size(examples,1);      %nn number of examples
        ns=size(examples,2);      %ns number of samples in example
        freqs=1/(dt1+dt2)*(1:ns); %proper fft frequencies
        
        
        %~~~PHASE-EQUILIZATION ('common-delay') ?IS THIS NECESSARY
        frqmult=repmat(repmat(1:maxFreq,[nn,1]),[1,1,nch]);
        z=examples./(abs(examples)+1E-6);
        z(examples==0)=1;
        a=angle(prod(prod(z,3),2));
        a=a/sum(1:maxFreq)/nch;
        examples=exp(-1i*repmat(a,[1 maxFreq nch]).*frqmult).*examples;
        
        %ft features per example
        examples=reshape(examples,nn,[]);
        %DEBUG
        dbgexamples=reshape(dbgexamples,nn,[]);
        %DEBUG
        
        %define some constants during first pass
        if isempty(this.freqid)
          frqs=repmat(freqs,nch,1)';
          chs=repmat(chidx(:)',maxFreq,1);
          this.freqid=reshape(frqs,1,[]);   %frequency of feature
          this.chid=reshape(chs,1,[]);      %channel of feature
          this.ftidx=[this.freqid<=5,this.freqid<=5];  %ft-feature selector
        end
        
        %grow this.examples and this.labels, if necessary
        if(this.nexamples+nn>size(this.examples,1))
          this.examples=cat(1,this.examples,zeros(1000,2*size(examples,2)));
          this.labels=cat(1,this.labels,zeros(1000,1));
          %DEBUG
          this.rawexamples=cat(1,...
            this.rawexamples,zeros(1000,size(dbgexamples,2)));
          this.offsetexamples=cat(1,this.offsetexamples,zeros(1000,1));
          %DEBUG
        end
        
        %copy examples to this.examples and this.labels
        this.labels(this.nexamples+1:this.nexamples+nn)=markers;
        this.examples(this.nexamples+1:this.nexamples+nn,:)=...
          [real(examples),imag(examples)];
        %DEBUG
        this.rawexamples(this.nexamples+1:this.nexamples+nn,:)=dbgexamples;
        this.offsetexamples(this.nexamples+1:this.nexamples+nn,:)=xidx;
        %DEBUG
        this.nexamples=this.nexamples+nn;
        
        %reset last_trigger and last_example
        if ~isempty(xidx_deferred)
          this.last_trigger=min(xidx_deferred-ddt);
          this.last_example=min(xidx_deferred-dt);
        else
          this.last_trigger=0;
          this.last_example=curr_pos;
        end
        
        if this.flag_debugon
          fprintf('(total %i)\n',this.nexamples);
        end
        
        %###OFFER CLASSIFICATION
        if ~isempty(this.osvm)
          [val mcmatrix]=this.ownclassify(this.osvm,...
            this.examples(this.nexamples,this.ftidx));
          if this.flag_debugon
            fprintf('Examples: classification of %i@%i is %i\n',...
              markers(end),xidx(end),val);
          end
          
          %detection feedback indicator
          if this.flag_fbindicatoron
            if this.xState(1)~=0
              delete(this.xState(1));
            end
            
            this.xState(1)=annotation(this.fig,...
              'rectangle',this.hbox2{val},'LineWidth',2,...
              'FaceColor','flat','Color',[1 0.65 0]);
          end
          
          %detection feedback matrix
          if this.flag_mcmatrixon
            order=[1 3 2 4 6 5];
            order=order(ismember(order,this.targets));
            axes(this.hmcmatrix);
            imagesc(mcmatrix(order,order)');
            colormap gray
            set(gca,'xtick',[1 2 3 4 5 6]);
            set(gca,'ytick',[1 2 3 4 5 6]);
            title('Detection matrix')
          end
          
          %CONTROL MODEL
          if this.hhmode==0
            this.hhmode=annotation(this.fig,...
              'textbox',[0.16 0.927 0.100 0.065],...
              'String','L|R','FontSize',18,'FontWeight','bold',...
              'FitBoxToText','off','LineStyle','none');
          end                    
          
          %set control state variable
          if val==3
            this.ccmode=~this.ccmode;
            this.ccstate=0;
            
            if ~this.ccmode
              set(this.hhmode,'String','L|R');
            else
              set(this.hhmode,'String','F|B');
            end            
          elseif val==1
            if ~this.ccmode
              %left turn
              this.ccstate=1;
              set(this.hhmode,'String','L|R - L');
            else
              %back move
              this.ccstate=5;
              set(this.hhmode,'String','F|B - B');
            end
          elseif val==2
            if ~this.ccmode
              %right turn
              this.ccstate=2;
              set(this.hhmode,'String','L|R - R');
            else
              %forward move
              this.ccstate=4;
              set(this.hhmode,'String','F|B - F');
            end            
          else
            %stop motion
            this.ccstate=0;
          end
          
          %show/hide "HOLD" sign
          if val==6 && this.flag_fbindicatoron
            if isempty(this.gHandles) || this.gHandles(1)==0
              this.gHandles(1)=annotation(this.fig,...
                'textbox',[0.006 0.927 0.100 0.065],...
                'String','HOLD','FontSize',18,'FontWeight','bold',...
                'FitBoxToText','off','LineStyle','none');
            else
              delete(this.gHandles(1));
              this.gHandles(1)=0;
            end
          end
        end
      end
      
      
     if this.flag_debugon
       fprintf('Examples: dt %i\n',toc-timein);
     end   
    end

        
  end
  
  %Methods accessible to user
  methods (Access = public)
    function this = nkiui2(acqtime,flag_dataon,flag_stateon)
      % process inits and flags
      if nargin<1
        acqtime = [];
      end
      if nargin<2
        flag_dataon = true;
      end
      if nargin<3
        flag_stateon = true;
      end      
           
      this=this@nkiui(acqtime,flag_dataon,flag_stateon);
      
      this.maxcue=3;
      this.flag_mcmatrixon=false;
      this.flag_fbindicatoron=false;
      this.nexamples=0;
      this.examples=[];
      this.labels=[];            
    end
    
    function prepare_disp(this)
      %call superclass' prepare display
      prepare_disp@nkiui(this)
      
      %override interactive trigger box
      this.hbox1{end}=[0.34 0.93 0.16 0.07];
        
    end
            
end
  
end