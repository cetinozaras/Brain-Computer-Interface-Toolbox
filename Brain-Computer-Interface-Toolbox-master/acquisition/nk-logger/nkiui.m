classdef nkiui < nklogger
  % Nihon Kohden Interactive User Interface class.
  %
  % Usage:
  % [TO CREATE INSTANCE]
  % nk=nkiui(duration);
  %
  % [TO REPLAY DATA]
  % nk.replay=replay; nk.program=program;
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
  % v1.01 2016-04-21
  %   - redesigned prepare_prg function, now takes string sequence of
  %   sessions to define the outline of an experiment program, use S
  %   for normal session, B for break, I for interactive; for example,
  %   "SBIBS"
  %   - added flags to control all elements of feedback mechanism,
  %   including robot anim, detection matrix anim, detection squares
  %    robot animation -> nk.flag_animon
  %    detection matrix -> nk.flag_mcmatrixon
  %    detection indicator -> nk.flag_fbindicatoron
  %   set these to false before running to disable any one of these.
  % 
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
  end
  
  %Hidden properties accessible to experiment implementations
  properties (Access = protected)
    hState=[];      %graphical objects holder
    xState=[];      %second graphical objects holder (for classifier)
    gHandles=[];    %persistent graphics object handles
    
    hbox1=[];       %trigger box coordinates
    hbox2=[];       %detection box coordinates
    
    haxmain=0;      %main axis    
    
    cstate=0;       %ui/cue current state
    pstate=0;       %ui/cue previous state
    ccstate=0;      %current control state
    
    last_example=0;   %time of acquiring last sample
    last_trigger=0;   %time of last trigger        
    last_trained=0;   %last time detector retrain    
    last_animation=0; %last animation time
    
    hmcmatrix=0;        %online feedback axis
    last_mcmatrix=0;    %last online feedback 
    
    serial1=[];          %serial port handle used for trigger EEG channel
  end
  
  %Read-only public properties accessible to user
  properties(GetAccess = public, SetAccess = protected)
    freqid=[];        %frequency/channel ids for this.examples
    chid=[];            
    osvm=[];          %mc-svm set    
  end
  
  %Read-only public properties accessible to user
  properties (GetAccess = public, SetAccess = private)
    
  end
  
  %Read-write public properties accessible to user
  properties  (Access = public)    
    fig_ipos=[527 56 836 616];  %initial position of the figure
    flag_triggerdata=true;      %send trigger to EEG trigger channel 
    flag_animation=true;        %show effector animation
    
    %PROGRAMMING SECTION
    maxcue=6;         %cues to use
    twait=120;        %initial relaxation wait, sec
    trial_num=300;    %trials per session
    break_time=120;   %in-between sessions break, sec
    program=[];       %trigger program, manually specify if needed
    
    flag_animon=true; %robot animation is on
    flag_mcmatrixon=true; %detection-feedback matrix is on
    flag_fbindicatoron=true;  %feedback detecton indicator

    train_delay = 300;  %delay before starting detector training, trials
    train_period=25;    %period for re-training detector, trials
    
    interactive_cue=7;  %cue state for interactive-response signal

    
    
    %DETECTOR CONFIG SECTION
    dt1=0;            %epoch start (pre-trigger, sec)
    dt2=0.85;         %epoch start (post-trigger, sec)
    targets=[3,1,2,4,5,6];  %detection targets, arrange in the order 
                      %of priority, highest priority - first, 
                      %effective in detection in the case of ties
    chidx=1:21;       %valid data channels
    sets={};          %bisection sets, manually specify if needed
    ftidx=[];         %ft-feature selector, manually specify if needed
        
    examples=[];      %exampels of events' features
    labels=[];        %labels of events in examples
    nexamples=0;      %number of examples collected
    ispretrained=false;  %is pretraining data provided in examples   
    
    triggerthresh=30;    %trigger thrshold for fine-tuning search of 
                         %BCI response examples in trigger feedline
    triggerdt=1.0;       %allowed uncertainty around internal trigger
                         %time record
    triggerch=22;        %trigger channel
    
    amarker=[];       %actual marker detections (from trigger channel)
    
    %DEBUGING
    cchistory=[];        %history of cc-state of the robot
    osvmhistory={};
    rawexamples=[];
    offsetexamples=[];
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
          
          %set control state variable
          if val==3
            %do nothing, ie continue
          elseif val==this.ccstate
            %stop motion
            this.ccstate=0;
          else
            %start motion
            this.ccstate=val;
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
        
    %train bci detector
    function retrain_detector(this)
      timein=toc;
      
      xvalthr=0.70;     %train-validation split
      
      %NOTE --- may want to discard old examples above nnmax ---      
      nnmax=10000;      %max training samples to use
      %NOTE
      
      sets=this.sets;   %bisection sets      
      ftidx=this.ftidx; %feature selector
            
      %Prepare & train pairwise SVMs
      osvm=cell(size(sets));
      
      %train-validation split
      nn=this.nexamples;      
      act_flgtrain=rand(1,nn)<xvalthr;
      
      %mix and restrict training samples count
      idx=find(act_flgtrain);
      %%this randomly shuffles exampels to be used
      %idx=idx(randperm(length(idx)));
      
      %select last nnmax features 
      idx=idx(end-min(length(idx),nnmax)+1:end);
      xeegsamples=this.examples(idx,ftidx);
      xmrktargets=this.labels(idx);
      
      for k=1:length(sets)
        %restrict training examples to contained in sets{k}
        idx=ismember(xmrktargets,sets{k});
        
        if isempty(idx) continue; end
        
        xxeegsamples=xeegsamples(idx,:);
        xxmrktargets=xmrktargets(idx);
        xxmrktargets=(xxmrktargets==sets{k}(1));
        
        if length(unique(xxmrktargets))<2 continue; end
        
        %train SVM
        options=optimset('MaxIter',10000);
        svm2=svmtrain(xxeegsamples,xxmrktargets,'Method','LS',...
          'QuadProg_Opts',options);
        
        %extract SVM model val<-w2*x'-b2
        b2=svm2.Bias;
        w2=svm2.SupportVectors'*svm2.Alpha;
        w2=w2.*svm2.ScaleData.scaleFactor';
        b2=b2+svm2.ScaleData.shift*w2;
        w2=-w2;
        
        o=[];
        o.w2=w2;
        o.b2=b2;
        o.bbef2=0;
        
        osvm{k}=o;
      end
      
      %export result
      this.osvm=osvm;
      this.last_trained=this.nexamples;
      
      if this.flag_debugon
        %check performance on training set
        xtest=this.ownclassify(osvm,xeegsamples);
        perf=(xmrktargets==xtest);
        perf=perf(ismember(xmrktargets,this.targets));
        p1=mean(perf);
        
        %check performance on xvalidation set
        idx=find(~act_flgtrain);
        xeegsamples=this.examples(idx,ftidx);
        xmrktargets=this.labels(idx);
        vals1=this.ownclassify(osvm,xeegsamples);
        vals=xmrktargets;
        perf=(vals==vals1);
        perf=perf(ismember(vals,this.targets));
        p2=mean(perf);
        
        %store classifier
        this.osvmhistory{end+1}={osvm,p1,p2};        
        
        fprintf('##########################################\n');
        fprintf('Detector:\n');
        fprintf(' examples %i\n training %g\n',nn,p1);
        fprintf(' xvalidation %g\n',p2);
        fprintf(' dt %g\n',toc-timein);
        fprintf('##########################################\n');
      end
      
    end
     
    %calculate online feedback matrix
    function online_feedback(this)
      if isempty(this.osvm)
        return;
      end
      
      timein=toc;
      
      dt1=this.dt1;       %epoch start (pre-trigger, sec)
      dt2=this.dt2;       %epoch end (post-trigger, sec)
      chidx=this.chidx;   %valid data channels
      nch=length(chidx);     %number of data channels
      
      %get the fragment of data not yer processed
      tp=max(this.gCounter);     
      dt=ceil(this.sampFreq*(dt1+dt2));
      
      if tp-dt<0 
        return;
      end
      
      example=this.outputMatrix(tp-dt+1:tp,chidx);
      
      ns=size(example,1);      %ns number of samples in example
      
      %calculate FT features, (keep 2:maxFreq+1)
      example=fft(example,[],1)/(this.sampFreq/200);
      maxFreq=floor((ns-1)/2);
      example=example(2:1+maxFreq,:);
      
      %~~~PHASE-EQUILIZATION ('common-delay')
      frqmult=repmat((1:maxFreq)',[1,nch]);
      z=example./(abs(example)+1E-6);
      z(example==0)=1;
      a=angle(prod(prod(z,2),1));
      a=a/sum(1:maxFreq)/nch;
      example=exp(-1i*repmat(a,[maxFreq nch]).*frqmult).*example;
      
      %ft features per example
      example=reshape(example,1,[]);
      example=[real(example),imag(example)];
      
      %reset last_mcmatrix
      this.last_mcmatrix=tp;
      
      %offer classification
      [val mcmatrix]=this.ownclassify(this.osvm,example(1,this.ftidx));
            
      axes(this.hmcmatrix);
      imagesc(mcmatrix');      
      colormap gray
      axis equal      
      
      if this.flag_debugon
        fprintf('Feedback drawn @ %i dt %g\n',tp,toc-timein);
      end      
    end    
    
    %logistic function
    function z=logit(this,x)
      z=2./(1+exp(-x))-1;
    end
    
    %classify using SVM model object
    function [labels mcmatrix]=ownclassify(this,osvm,xeegsamples)
      nn=max(this.targets);   %number of different labels
      nt=size(xeegsamples,1); %number of examples
      votes=zeros(nt,nn);     %votes
      
      sets=this.sets;           %bisection sets
      reorder=this.targets(:);  %priority order for ties
      
      if nargout>1
        mcmatrix=zeros(nn,nn);
      end
      
      for k=1:length(sets)
        if isempty(osvm{k}) continue; end
        
        w2=osvm{k}.w2;
        b2=osvm{k}.b2;
        bbef2=osvm{k}.bbef2;
        
        %obtain SVM values
        valsd=-b2+xeegsamples*w2;
        vals1=(sign(valsd-bbef2)+1)/2;
        
        if nargout>1
          mcmatrix(sets{k}(1),sets{k}(2))=this.logit(valsd);
          mcmatrix(sets{k}(2),sets{k}(1))=this.logit(-valsd);
        end
        ii=sets{k}(1);
        jj=sets{k}(2:end);
        votes(vals1>0,ii)=votes(vals1>0,ii)+1;
        votes(vals1==0,jj)=votes(vals1==00,jj)+1;
      end
      
      %reorder targets in votes, to specify labels priority
      %earlier targets will be returned on ties according to how max works
      votes=votes(:,reorder);      
      [g labels]=max(votes,[],2);
      labels=reorder(labels);
    end
        
  end
  
  %Methods accessible to user
  methods (Access = public)
    function this = nkiui(acqtime,flag_dataon,flag_stateon)
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
           
      this=this@nklogger(acqtime,flag_dataon,flag_stateon);
      
      this.nexamples=0;
      this.examples=[];
      this.labels=[];            
    end
    
    function out = getData(this)
      % write out the data
      n=this.nS;                  %total samples
      out=struct('id',this.idtag,'tag','','nS',n,'sampFreq',this.sampFreq,...
        'marker',this.amarker(1:n),'marker_old',this.marker(1:n),...
        'data',this.outputMatrix(1:n,:),'chnames',[],'binsuV',1);
      out.chnames=this.DataChannels.ChannelsHumanNames;
    end    
    
    %produce examples for a pre-trained file
    function pretrain_examples(this,datas,markers)
      this.nexamples=0;
      this.examples=[];
      this.labels=[];      
      
      dt1=this.dt1;       %epoch start (pre-trigger, sec)
      dt2=this.dt2;       %epoch end (post-trigger, sec)
      chidx=this.chidx;   %valid data channels
      targets=this.targets;  %target events
      nch=length(chidx);     %number of data channels
      
      for i=1:length(datas)
        %get data from ith dataset
        data=datas{i};
        marker=markers{i};
      
        %construct epochs
        dt=ceil(this.sampFreq*(dt1+dt2)); %total epoch length, samples
        ddt=ceil(this.sampFreq*dt2);      %epoch length after trigger
      
        idx=find(diff(marker)>0);     %stimulus on-edge
        idxon=idx(1:end)+ddt;
        xidx=idxon;
      
        xmarker=marker(xidx-ddt+1);   %epochs' trigger values
      
        %keep only events within 'targets'
        idx=1:length(xidx);
        idx=idx(ismember(xmarker,targets));
      
        %if nothing here, return now
        if isempty(idx)
          return;
        end
      
        %prepare new examples within 'targets'
        xidx=xidx(idx);
            
        nn=length(idx);
        examples=zeros(nn,dt,nch);
        for k=1:nn
          tp=xidx(k);        %kth epoch end point
          examples(k,:,:)=data(tp-dt+1:tp,chidx);
        end
        xmarker=xmarker(idx);
      
        %ns number of samples in one example == (dt1+dt2)*sampFreq
        ns=size(examples,2);     
      
        %calculate FT features, (keep 2:maxFreq+1)
        examples=fft(examples,[],2)/(this.sampFreq/200);
        maxFreq=floor((ns-1)/2);
        examples=examples(:,2:1+maxFreq,:);
      
        nn=size(examples,1);      %nn number of examples
        ns=size(examples,2);      %ns number of samples in example
        freqs=1/(dt1+dt2)*(1:ns); %fft frequencies
            
        %~~~PHASE-EQUILIZATION ('common-delay')
        frqmult=repmat(repmat(1:maxFreq,[nn,1]),[1,1,nch]);
        z=examples./(abs(examples)+1E-6);
        z(examples==0)=1;
        a=angle(prod(prod(z,3),2));
        a=a/sum(1:maxFreq)/nch;
        examples=exp(-1i*repmat(a,[1 maxFreq nch]).*frqmult).*examples;
      
        %ft features per example
        examples=reshape(examples,nn,[]);
            
        this.examples=cat(1,this.examples,[real(examples),imag(examples)]);
        this.labels=cat(1,this.labels,xmarker);
        this.nexamples=this.nexamples+nn;
      end
      
      %other variables
      frqs=repmat(freqs,nch,1)';
      chs=repmat(chidx(:)',maxFreq,1);
      this.freqid=reshape(frqs,1,[]);
      this.chid=reshape(chs,1,[]);
      this.ftidx=[this.freqid<=5,this.freqid<=5];
      
      this.ispretrained=true;
    end
            
    %[prepare UI program]
    function prepare_prg(this,prgdesign)
      %initialize design      
      if nargin<2 || isempty(prgdesign)
        prgdesign='SBSBS';
      end
      
      maxcue=this.maxcue;
      twait=this.twait;
      trial_num=this.trial_num;
      break_time=this.break_time;
      
      if this.flag_debugon
        fprintf('Preparing program, design variable ''%s''\n',prgdesign);
        fprintf('maxcue %g\n',maxcue);
        fprintf('twait %g\n',twait);
        fprintf('trials per session %g\n',trial_num);
        fprintf('breaks duration %g\n',break_time);
        fprintf('--------------------\n');
      end
      
      %prepare sequential trigger program
      seq_program=zeros(1,3*length(prgdesign)*trial_num+1000);
      ipos=0;
      
      %initial relaxation trigger
      seq_program(ipos+1:ipos+3)=[90 0 twait];
      ipos=ipos+3;
      if this.flag_debugon
        fprintf('writing initial relaxation segment, 3 positions written\n');
      end          
      
      
      %initial syncronization sequence        
      seq_program(ipos+1:ipos+15)=[99 5 1 99 4 1 99 3 1 99 2 1 99 1 1];
      ipos=ipos+15;      
      if this.flag_debugon
        fprintf('writing sync segment, 15 positions written\n');
      end          
      
      
      %session runs
      for s=1:length(prgdesign)
        if strcmpi(prgdesign(s),'S')
          %write regular trials         
          for k=1:trial_num
            %trigger wait interval, random 1.5-2.5 sec
            tbrk=1*rand+1.5;
            %trigger length
            tact=1;
            %trigger value
            cue=randi(maxcue);
    
            seq_program(ipos+1:ipos+3)=[cue tbrk tact];
            ipos=ipos+3;
          end
          
          if this.flag_debugon
            fprintf('writing S-session, %i positions written\n',trial_num);
          end          
        elseif strcmpi(prgdesign(s),'B')        
          %write break
          seq_program(ipos+1:ipos+3)=[91 0 break_time];
          ipos=ipos+3;
          if this.flag_debugon
            fprintf('writing Break, %i positions written\n',3);
          end          
        elseif strcmpi(prgdesign(s),'I')
          %write interactive free trials
          for k=1:trial_num
            %trigger wait interval, constant 2.0 sec
            tbrk=2.0;
            %trigger presentation interval, constant 1.0 sec
            tact=1.0;
            %interactive response trigger value, this.interactive_cue
            cue=this.interactive_cue;
    
            seq_program(ipos+1:ipos+3)=[cue tbrk tact];
            ipos=ipos+3;
          end     
          
          if this.flag_debugon
            fprintf('writing I-session, %i positions written\n',trial_num);
          end          
        end
      end
      
      %session end signal
      seq_program(ipos+1:ipos+3)=[92 0 1];
      ipos=ipos+3;
      
      seq_program=seq_program(1:ipos);
      
      if this.flag_debugon
        fprintf('written %i positions\n',ipos);
      end 
      
      %fill-in the per-sample program array
      total_time=sum(seq_program(2:3:end)+seq_program(3:3:end));
      this.program=zeros(1,ceil(this.sampFreq*total_time),'uint8');
      ipos=0;
      currt=0;
      while(ipos<length(seq_program))
        cue=seq_program(ipos+1);
        idxbegin=floor((currt+seq_program(ipos+2))*this.sampFreq);
        idxend=ceil((currt+seq_program(ipos+2)...
          +seq_program(ipos+3))*this.sampFreq);
        
        this.program(idxbegin+1:idxend)=cue;
        
        currt=currt+seq_program(ipos+2)+seq_program(ipos+3);
        ipos=ipos+3;
      end
      
      %reset acqusition time
      this.acqTime=currt+30;
      
      if this.flag_debugon
        fprintf('--------------------\n');
        fprintf('written this.program\n');
        fprintf('program length %i\n',length(this.program));
        fprintf('program acqusition time %g\n',this.acqTime);
        fprintf('Quiting\n');
      end       
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
      
      if this.flag_debugon
          %fprintf('Pausing for 1 sec ...\n');
          %pause(1);
      end
      
      %open trigger channel
      if this.flag_triggerdata && this.flag_dataon
        fprintf('TRIGGER: Try to open serial connection to COM3\n');
        
        try
          this.serial1=serial('COM3', 'BaudRate', 9600);
          fopen(this.serial1);                    
          fprintf('TRIGGER: opened serial connection to COM3\n');
          fprintf('TRIGGER: trigger data will be sent to COM3\n');
        catch e          
          fprintf('TRIGGER: failed to open serial connection to COM3\n');
          fprintf('TRIGGER: trigger data will not be sent\n');          
          this.serial1=[];          
        end        
      end
      
      figure(this.fig)
      clf
      %set(this.fig,'Position',[228 28 1137  644]);
      %set(this.fig,'Position',[219 256 548 416]);
      set(this.fig,'Position',this.fig_ipos);
      set(this.fig,'Color',[1 1 1]);      
      %set(this.fig, 'menubar', 'none');
      
      %can speed up 3D rendering
      set(this.fig,'Renderer','painters');
      
      imgnames={'lefthand.png','pass.png','righthand.png','leftfoot.png',...
        'tongue.png','rightfoot.png'};
      imgs=cell(1,length(imgnames));
      maps=cell(1,length(imgnames));
      warning off all
      for i=1:length(imgnames)
        [imgs{i} maps{i}]=imread(imgnames{i});
      end
      warning on all
      
      this.haxmain=axes('Position',[0.01 0.01 0.98 0.98]);
      box on
      
      %robot arm
      puma3d(this.fig,this.haxmain)

      %classification feedback matrix
      if this.flag_mcmatrixon
        this.hmcmatrix=axes('Position',[0.8 0.78 0.18 0.18]);
        axis off
      end
      
      %axis boxes
      habox={[0.35 0.94 0.04 0.05],
        [0.40 0.94 0.04 0.05],
        [0.45 0.94 0.04 0.05],
        [0.50 0.94 0.04 0.05],
        [0.55 0.94 0.04 0.05],
        [0.60 0.94 0.04 0.05]};
      
      %trigger icons
      for i=1:6
        axes('Position',habox{i});
        imshow(imgs{i},maps{i});
      end
      
      %detection icons
      if this.flag_fbindicatoron
        dh=[0 -0.06 0 0];
        for i=1:6
          axes('Position',habox{i}+dh);
          imshow(imgs{i},maps{i});
        end
      end
      
      %indicator boxes
      %(!) order 1 3 2 4 6 5 == LH RH N LL RL T
      reorder=[1 3 2 4 6 5];
      this.hbox1=cell(1,6);
      for i=1:6 this.hbox1{i}=habox{reorder(i)}; end      
      if this.flag_fbindicatoron
        this.hbox2=this.hbox1;
        for i=1:6 this.hbox2{i}=this.hbox2{i}+dh; end
      end
      
      %add interactive sessions blinker
      this.hbox1{end+1}=[0.65 0.94 0.04 0.05];
      
      %clear all handles
      for i=find(this.hState) this.hState(i)=0; end
      
      %reset experiment-specific variables
      this.cstate=0;
      this.pstate=0;
      this.ccstate=0;
      this.xState=0;      
      this.last_trigger=0;
      this.last_example=0;
      this.last_mcmatrix=0;
      this.amarker=zeros(size(this.marker));
      
      this.osvm=[];
      this.last_trained=0;
      
      if(isempty(this.sets))
        k=1;
        for i=1:length(this.targets)
          for j=i+1:length(this.targets)
            this.sets{k}=[i j];
            k=k+1;
          end
        end
      end
      
      if ~this.ispretrained
        this.nexamples=0;
        this.examples=[];
        this.labels=[];
      end
      
      if this.flag_debugon
        %debug cc-hisotry holder
        this.cchistory=zeros(size(this.marker));
      end
      
    end
    
    
    %HOOK: this.finalize_disp
    %[finalize GUI]
    %This function is responsible for closing GUI according
    %to experiment's design. Experiment designer is responsible 
    %for writing this function. This function is called after 
    %the data acquisition loop concluded.
    function finalize_disp(this)
      %shut down trigger port
      if ~isempty(this.serial1)
        fprintf('TRIGGER: Closing COM3\n');
        fprintf(this.serial1,'S');
        fclose(this.serial1);
        this.serial1=[];
      end
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
    function preupdate_state(this,time)
        
    end
    
    %HOOK: this.update_state
    %[update GUI and state variables]
    %This function is responsible for updating GUI according
    %to experiment program and doing any other actions to record
    %experiment's trigger program. This function maintains this.marker
    %array of the experiment's trigger record. Experiment designer is
    %responsible for writing this function. This function is called
    %at each data-acquisition cycle after new data bactch had been
    %acquired.
    %Example below will draw EEG graphs in GUI figure.
    function update_state(this,time)
      if this.nS==0 && min(this.gCounter)==0
        return;
      end
      
      timein=toc;
            
      figure(this.fig)
      
      %raw EEG
      %axes(this.hmcmatrix);
      %this.update_eeggraph(this.DataChannels.EEGChannels,[],1);
      %legend('off')
      
      %update this.marker
      this.marker(this.nS+1:min(this.gCounter))=this.cstate;
      
      %select next gui state
      curr_pos=min(this.gCounter);
      if curr_pos<=length(this.program)
        this.cstate=this.program(curr_pos);
      end            
      
      if this.pstate~=this.cstate
        %clear graphic elements
        for i=find(this.hState)
          if(this.hState(i)~=0)
            delete(this.hState(i));
            this.hState(i)=0;
          end
        end
        
        %clear x-graphic elements
        if this.cstate~=0
          %delete xState if present (here)
          if(this.xState(1)~=0)
            delete(this.xState(1));
            this.xState(1)=0;
          end
        end  

        %send trigger data to trigger port
        if ~isempty(this.serial1)
          if this.cstate~=0
            %send "baslangic" to trigger port
            fprintf(this.serial1,'B');
          else
            %send "sonuc" to trigger port
            fprintf(this.serial1,'S');            
          end        
        end
        
        %redraw graphic elements
        if this.cstate>=1 && this.cstate<=length(this.hbox1)
           this.hState(1)=annotation(this.fig,...
             'rectangle',this.hbox1{this.cstate},'LineWidth',2,...
             'FaceColor','flat','Color',[1 0 0]);
           
          %update this.last_trigger
          if(this.last_trigger==0)
            this.last_trigger=curr_pos;
          end
        elseif this.cstate==90 % || this.cstate==99
          this.hState(1)=annotation(this.fig,...
            'textbox',[0.1154 0.4365 0.7751 0.2437],...
            'String',{'Initial Relaxation','PLEASE RELAX'},...
            'FontSize',50,'BackgroundColor',[1 1 1],...
            'FitBoxToText','off',...
            'LineStyle','none');
        elseif this.cstate==91
          this.hState(1)=annotation(this.fig,...
            'textbox',[0.1154 0.4365 0.7751 0.2437],...
            'String',{'Break Time...','PLEASE RELAX'},...
            'FontSize',50,'BackgroundColor',[1 1 1],...
            'FitBoxToText','off',...
            'LineStyle','none');
        elseif this.cstate==92
          this.hState(1)=annotation(this.fig,...
            'textbox',[0.1154 0.4365 0.7751 0.2437],...
            'String',{'Session Ended','THANK YOU!'},...
            'FontSize',50,'BackgroundColor',[1 1 1],...
            'FitBoxToText','off',...
            'LineStyle','none');
        end
      end
      
      this.pstate=this.cstate;      
      
      
      %================================================================
      %DETECTOR PROCESSING      
      %update examples
      if this.last_trigger>0 && ...
          (curr_pos-this.last_trigger)>this.dt2*this.sampFreq
        this.collect_examples();
      end
      
      %retrain bci-detector
      if (this.nexamples>this.train_delay) && ...
          ((this.nexamples-this.last_trained)>=this.train_period)          
        this.retrain_detector();
      end
      
      
      %================================================================
      %ROBOT ANIMATION
      %update puma3d position
      if this.flag_animation && this.last_animation>0
        dt=time-this.last_animation;
      
        switch this.ccstate
          case 1
            dphi=10*[1 0 0 0 0 0]*dt;
          case 2
            dphi=10*[-1 0 0 0 0 0]*dt;
          case 4
            dphi=puma3d_getdt(5*dt);
          case 5
            dphi=puma3d_getdt(-5*dt);
          otherwise
            dphi=[];
        end
        
        if ~isempty(dphi) && this.flag_animon
          puma3d_control(dphi,0);
        end
      end
      
      this.last_animation=time;           
            
      if this.flag_debugon
        fprintf('GUI: time %g:%i state %i->%i dt %g\n',...
          time,curr_pos,this.pstate,this.cstate,toc-timein);
        this.cchistory(this.nS+1:min(this.gCounter))=this.ccstate;
      end      
    end
    
   function test_detector(this)
      tic
      this.retrain_detector();
   end
    
end
  
end