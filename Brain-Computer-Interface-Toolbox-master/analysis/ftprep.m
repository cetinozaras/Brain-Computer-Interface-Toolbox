function [ft mrk]=ftprep(datafiles,dt1,dt2,chidx,R,ftid)
%[ft mrk]=ftprep(datafiles,dt1,dt2,chidx,chref,ftid)
% Computes features for analysis of EEG BCI data. 
% 'datafiles' is a cell array of file names pointing to the EEG data to 
% be processed. The EEG data in all data-files should be stored uniformly 
% in the variable 'o', in the output format of emologger. 
% 'dt1' and 'dt2' are the before-stimulus and after-stimulus offsets 
% defining trial windows, in seconds. Positive dt1 is the offset prior to 
% the stimulus onset, and positive dt2 is the offset past the stimulus 
% onset.
% 'chidx' is the array of indexes of the channels from the variable o.data 
% in the datafiles that carry useful EEG data.
%'chref' is the specifier of referencing type to be used with the EEG data. 
% For example, this can be chosen as one reference channel, or the average of 
% the ground channels (A1 and A2), or the average of all channels, or the 
% average of neighbor channels (so called Laplace reference). You can 
% specify 'chref' as either an array of channel-ids whose average will be
% used as the reference and subtracted from the EEG channels in o.data, 
% or as a matrix [n_channels x n_channels] such that 
% EEG(t,chidx)<-EEG(t,chidx) - EEG(t,chidx)*Reference(:,:)' 
% (for instance, for Laplace referencing).
%
% The optional parameter 'ftid' is the string specifying the type of the 
% features intended to be used downstream from ftprep.
%
% The output is the structure 'ft' containing time-series and FT-features 
% and companion information, per each BCI trial in the EEG data, as well as 
% the array 'mrk' of the BCI control state-labels for each trial. 
%
% ftprep returns time-series features (tseries), FT amplitude features 
% (ft), Power Spectral Density features (PSD, as amplitude^2), cepstrum 
% (CPM, as ifft(log(PSD)) and EEG band-power features for the standard 
% EEG band definition (as amplitude^2).
%
% Example usage:
%  [ft ftmrk]=ftprep({'nkdeney-example.mat'},0,0.85,1:21,11:12);
%
% Y.Mishchenko (c) 2015


%% Greetings ;)
%datafiles examples
%(!)all data in datafiles should be in variables 'o'(!)
%(!)can mix datafiles with different sampling frequencies, but should be 
%strict integer multiples(!)
%example of giving multiple datafiles as input
% datafiles={'pilot20150618-1.mat','pilot20150618-1.mat',...
%  'pilot20150618-3.mat','pilot20150618-4.mat'};

fprintf('Preparing FT-features for following files:\n');
for idf=1:length(datafiles) fprintf(' %s\n',datafiles{idf}); end

if(nargin<2 || isempty(dt1)) dt1=0.5; end
if(nargin<3 || isempty(dt2)) dt2=1.0; end
if(nargin<4 || isempty(chidx)) chidx=1:size(o.data,2); end
if(nargin<5) R=[]; end
if(nargin<6) ftid=[]; end
nch=length(chidx);              %number of data channels

eegbands=[1 4 8 12 18 30 100];  %eeg-bands' corner frequency definitions
ofs=2.5*60;                     %initial segments to be discarded, seconds

xsamples=zeros(0,0,nch);
xftsamples=zeros(0,0,nch);
xmarkers=zeros(0,0);
for idf=1:length(datafiles)
  fprintf(' Reading %s...\n',datafiles{idf});
  
  %% read data
  load(datafiles{idf});
  
  %get sampling frequency
  sampFreq=o.sampFreq;
  
  %get EEG data
  eegdata=o.data(:,chidx);
  
  %get BCI marker
  %overwrite first two entries with 99, to facilitate discarding
  %of initial segments (below)
  marker=o.marker;
  marker([1 2])=[0 99];
  
  clear o
    
  %remove initial segment(s) (such as "relaxation" etc)
  %such segments should be marked in o.marker with label-id >= 90
  idx=find(diff(marker>=90)>0);
  idxon=idx(1:end);
  idx=find(diff(marker>=90)<0);
  idxoff=idx(1:end);
  for i=1:length(idxoff)
    marker(idxon(i):idxoff(i)+ofs*sampFreq)=0;
  end
  
  %perform EEG-data referencing
  fprintf(' Performing referencing...\n');
  if(isempty(R))  %nothing
    cmode=0;
  elseif(size(R,1)==1 || size(R,2)==1)  %R is a vector
    cmode=repmat(mean(eegdata(:,R),2),1,nch);
  else  %R is a matrix
    cmode=eegdata*R';
  end
  eegdata=eegdata-cmode;
  clear cmode
  
  %construct trials
  fprintf(' Finding trials...');
  [samples,markers]=trials_make2(eegdata,marker,dt1*sampFreq,dt2*sampFreq);
  nn=size(samples,1);     %nn is number of returned trials
  ns=size(samples,2);     %ns is number of samples, == (dt1+dt2)*sampFreq
                          %samples is nn x ns x nch 3d array
  fprintf(' %i trials found\n',nn);

  
  %% calculate FT features 
  fprintf(' Calculating FT features...\n');  
  % use fft--keep 2:maxFreq+1, where maxFreq=Ns/2, the independent 
  % features for real signal; fft is amplitude-normalized to 200Hz
  ftsamples=fft(samples,[],2)/(sampFreq/200);
  maxFreq=floor(ns/2);
  ftsamples=ftsamples(:,1:1+maxFreq,:);
  
  %~~~PHASE-EQUILIZE FT AMPLITUDES ('all-channels-one-delay')
  % NOTE: need find out the real importance for performance of this (???)  
  frqmult=repmat(repmat(0:maxFreq,[nn,1]),[1,1,nch]);
  z=ftsamples./(abs(ftsamples)+1E-6);  %{e^i*phi}'s 
  z(ftsamples==0)=1;
  %do prod to avoid issues with phi rotating through 2*pi
  a=prod(prod(z,3),2);
  a=angle(a);
  if maxFreq>0
    a=a/sum(1:maxFreq)/nch;
    ftsamples=exp(-1i*repmat(a,[1 maxFreq+1 nch]).*frqmult).*ftsamples;
  end
    
  
  %% special handling for ftid=tFRQxxx feature selector
  if length(ftid)>4 && strcmpi(ftid(1:4),'tFRQ')
    %extract FRQ cutoff
    cutoff_value=ftid(6:end);
    dash_position=strfind(cutoff_value,'-');
    if ~isempty(dash_position)
      %if cutoff is in the form 'XXX-XXX', make band-pass
      wband=[str2double(cutoff_value(1:dash_position-1)),...
                str2double(cutoff_value(dash_position+1:end))];
      wband=wband*2/sampFreq;
    else
      %if cutoff is in the form 'XXX', make low-pass
      wband=str2double(cutoff_value)*2/sampFreq;
    end
    
    %construct filter
    [z p k]=butter(8,min(1,wband));
    [sos,g]=zp2sos(z,p,k);
    hd=dfilt.df2tsos(sos,g);    
    
    %filter data
    eegdata=filter(hd,eegdata);
    
    %make samples again from filtered data
    samples=trials_make2(eegdata,marker,dt1*sampFreq,dt2*sampFreq);
    
    %subtract means from each channels
    %(this was done in dosvm2B but is somewhat illogical)
    %samples=samples-repmat(mean(samples,2),[1 size(samples,2) 1]);
    
    %(this should be completely fine (channel-means))
    cbase=mean(eegdata,1);
    cbase=reshape(cbase,[1 1 nch]);
    samples=samples-repmat(cbase,[nn size(samples,2) 1]);
  end
  
  
  %% merge samples, ftsamples & markers into common pull (xsamples etc)
  %if this sampFreq is higher than current, grow xsamples and xftsamples
  if size(xsamples,2)==0
    xsamples=reshape(xsamples,0,ns,nch);
    xftsamples=reshape(xftsamples,0,maxFreq+1,nch);    
  end
  
  if size(xsamples,2)<size(samples,2)
    fprintf(' A higher sampling frequency encountered, adjusting...\n');
    
    dns=size(samples,2)/size(xsamples,2);
    if dns-fix(dns)~=0
      fprintf(' Warning: Noninteger multiple sampling frequency!\n');
      dns=ceil(dns);
    end
    
    %adjust the size of xsamples array
    %spread-out recorded and interpolate missing values
    vartmp=zeros(size(xsamples).*[1 dns 1]);
    vartmp(:,1:dns:end,:)=xsamples;
    %interpolate missing samples
    varb=intfilt(dns,1,'Lagrange');
    vari=zeros(size(xsamples,1),dns,nch);
    vari(:,1,:)=2*xsamples(:,1,:)-xsamples(:,2,:);    
    vartmp=filter(varb,1,cat(2,vari,vartmp),[],2);    
    xsamples=vartmp(:,dns+1:end,:);
    
    %adjust the size of xftsamples array 
    %higher sampFreq only add extra frequencies to the right, 
    %the frequencies in ftsamples in initial segment are set 
    %by trial-window's length, ddt, and thus don't change
    dns=size(ftsamples,2)-size(xftsamples,2);
    vartmp=zeros(size(xftsamples,1),dns,nch);
    xftsamples=cat(2,xftsamples,vartmp);
    clear varb vari vartmp    
  end  
  
  %if this sampFreq is lower than current
  if size(samples,2)<size(xsamples,2)
    fprintf(' A different sampling frequency encountered, adjusting...\n');
    
    dns=size(xsamples,2)/size(samples,2);
    if dns-floor(dns)>0
      fprintf(' Warning: Noninteger multiple sampling frequency!\n');
      dns=floor(dns);
    end
    %adjust the size of samples array
    %spread-out recorded and interpolate missing values   
    vartmp=zeros(nn,size(xsamples,2),nch);
    vartmp(:,1:dns:end,:)=samples;    
    varb=intfilt(dns,1,'Lagrange');
    vari=zeros(nn,dns,nch);
    vari(:,1,:)=2*samples(:,1,:)-samples(:,2,:);        
    vartmp=filter(varb,1,cat(2,vari,vartmp),[],2);
    vartmp=vartmp(:,dns+1:end,:);
    xsamples=cat(1,xsamples,vartmp);
    
    dns=size(xftsamples,2)-size(ftsamples,2);
    vartmp=cat(2,ftsamples,zeros(nn,dns,nch));
    xftsamples=cat(1,xftsamples,vartmp);    
    clear varb vari vartmp
  else
    xsamples=cat(1,xsamples,samples);
    xftsamples=cat(1,xftsamples,ftsamples);    
  end
      
  xmarkers=cat(1,xmarkers,markers);
  
  clear samples ftsamples markers
end

%final values and frequencies
nn=size(xsamples,1);
nst=size(xsamples,2);
ns=size(xftsamples,2);
freqs=1/(dt1+dt2)*(0:ns-1);
fprintf(' Total trials %i\n',nn);
fprintf(' Spectral features %i\n',ns);
fprintf(' Time-series features %i\n',nst);




%% Preparing features
%~~~POWER SPECTRAL DENSITY (PSD)
fprintf('Calculating spectral power features...\n');
xpowsamples=abs(xftsamples).^2;

fprintf('Calculating cestrum features...\n');
xcpmsamples=real(ifft(log10(xpowsamples+1E-12)));

%~~~EEG BAND-POWERS
fprintf('Calculating EEG band-power features...\n');
cxpowsamples=cumsum(xpowsamples,2);
ff=freqs;
cbase=zeros(nn,1,nch);
xeegpowsamples=zeros(nn,length(eegbands),nch);
for k=1:length(eegbands)
  ffidx=find(eegbands(k)>=ff,1,'last');
  if isempty(ffidx) continue; end
  xeegpowsamples(:,k,:)=cxpowsamples(:,ffidx,:)-cbase;
  cbase=cxpowsamples(:,ffidx,:);
end
fprintf('Done\n');

%% store result
ft=[];

xsamples=reshape(xsamples,nn,[]);
xftsamples=reshape(xftsamples,nn,[]);
xpowsamples=reshape(xpowsamples,nn,[]);
xeegpowsamples=reshape(xeegpowsamples,nn,[]);

%Time-series features
ft.tseries=xsamples;

%Time-Series time-sample and channel identifier functions
z1=repmat(1:nst,nch,1)';
z2=repmat(chidx(:)',nst,1);
ft.tsampleid=reshape(z1,1,[]);
ft.tchid=reshape(z2,1,[]);


%FT real/imaginary features
ft.ft=xftsamples;

%FT PSD features
ft.pow=xpowsamples;

%FT cestrum features
ft.cpm=xcpmsamples;

%FT frequency and channel identifier functions (also applies to PSD)
z1=repmat(freqs,nch,1)';
z2=repmat(chidx(:)',1+maxFreq,1);
ft.freqid=reshape(z1,1,[]);
ft.chid=reshape(z2,1,[]);


%EEG band-powers
ft.eegpow=xeegpowsamples;

%EEG band-power frequency and channel identifier functions
z1=repmat(eegbands,nch,1)';
z2=repmat(chidx(:)',length(eegbands),1);
ft.eegfreqid=reshape(z1,1,[]);
ft.eegchid=reshape(z2,1,[]);


%total trials
ft.nn=nn;

%trial-labels
mrk=xmarkers;

end

