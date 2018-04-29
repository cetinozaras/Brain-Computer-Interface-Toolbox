function out=nkimport(nkdata,odata,nkmarker,io1,io2,xsign)
%o=nkimport(nkdata,odata,nkmarker,offset-o,offset-nk,1st-spike-polarity)
% Import nk data and transform to emotiv output-file format. Takes
% 'nkdata' and 'odata' - the file names of the m00 and omat files from the
% experiment. 'nkmarker' - the numeric id of the nkdata's channel
% containing the synchronizing marker signal. 'io1', 'io2' - numeric 
% alignment offsets in omat and nkdata data. Roughly, if set says that
% the time of the epoch io1 in omat marker output should be made equal
% to the time of the epoch io2 found via the synchronizing marker in nkdata
% output. Set both to [] to force automatic alignment discovery. 'xsign' 
% is the polarity assumed for the first spike in the nkdata synchronizing
% marker signal, set either +1 or -1. Set to [] to not use first spike
% polarity in epoch discovery (may be more susceptible to noise).
%
% Example of usage:
%  o=nkimport('nkdeney-eeg.m00','nkdeney-o.mat',22,[],[],-1)
%
%Y.Mishchenko (c) 2015
close all

%choose the nk channel containing marker signal
if(nargin<3 || isempty(nkmarker)) nkmarker=22; end
if(nargin<4) io1=[]; end
if(nargin<5) io2=[]; end
if(nargin<6) xsign=[]; end

%% Read data
fprintf('Reading data...');

%read nk-data
nkdata=nkascii2mat(nkdata);

if(nargin<2)
  out=[];
  out.id='';
  out.tag='NK-data import (raw)';
  out.sampFreq=1000/nkdata.ms_per_sample;
  out.nS=nkdata.num_dpoints;
  out.marker=zeros(size(nkdata.eeg,2),1);
  out.data=nkdata.eeg';
  out.chnames=nkdata.ch_names;
  out.binsuV=nkdata.binsuV;
  
  return
end

%read matlab marker data
R=load(odata);      %this will read o-variable
o=R.o;
idtag=o.idtag;

%read nk marker signal
z=nkdata.eeg(22,:);

%second and half-second width in samples
sec=1000/nkdata.ms_per_sample;
ds=round(sec/2);
frq=1000/nkdata.ms_per_sample;

% find threshold crossings
thrlow=40;
thrhigh=Inf;

%expect marker be positive spike followed by negative spike 1/2 second later
fprintf('Locating marker thr-crossings in nk-data...\n');
if(isempty(xsign))
  z2=(z(1:end-ds)-z(ds+1:end));
  zi=(abs(z2)>thrlow & abs(z2)<thrhigh);
  xsign=mean(sign(z2(zi)));
  fprintf('Estimated sync spike polarity as %g ...\n',xsign);
  xsign=sign(xsign);
end

z2=max(0,xsign*z(1:end-ds))+max(0,-xsign*z(ds+1:end));
zi=(z2>thrlow & z2<thrhigh);
%collect first crossings
zx=diff(zi);


%% relate 1st series
%it is important to get first+last times ti and tf, and initial offset
%io parameters right (for initial alignment)!
fprintf('Relating series...');
[ttimes1,tdurations1,tcues1]=aligndata(zx,o,io1,io2);

if(isempty(ttimes1))
  fprintf('Aligndata function failed to return any candidate alignment.\n');
  fprintf('Inspect the data manually and call nkimport with manual\n');
  fprintf('alignment offsets. Terminating...\n');
  out=[];
  return;
end


%% write out data
fprintf('Writing result...');

%form markers array
marker=zeros(nkdata.num_dpoints,1);
for i=1:length(ttimes1)
  tstart=ceil(ttimes1(i)*frq);
  tend=floor((ttimes1(i)+tdurations1(i))*frq);
  tcue=tcues1(i);
  marker(tstart:tend)=tcue;
end

out=[];
out.id=idtag;
out.tag='NK-data import (auto)';
out.sampFreq=frq;
out.nS=nkdata.num_dpoints;
out.marker=marker;
out.data=nkdata.eeg';
out.chnames=nkdata.ch_names;
out.binsuV=nkdata.binsuV;



  function [ntpoints,nchannels,bsweep,sampintms,binsuV,start_time,ch_names]=nkgetheader(fname)
    % Reads a Nihon Kohden EEG file in ASCII format (fname) and
    % returns 7 pieces of information from the header
    %
    % The function returns the following information:
    % ntpoints - number of data points per channel
    % nchannels - number of channels sampled during recording
    % bsweep - begin sweep (ms)
    % sampintms - sampling interval in ms
    % binsuV - number of bins per microvolts
    % start_time - starting time of recording
    % ch_names - char array of channel names
    %
    % Example:
    %  [tpoints,nchannels,bsweep,sampintms,binsuV,start_time,ch_names]=get_nkheader('TS003_LFP_SpatialWM.m00');
    %
    % Last modified 8/19/07 by TME
    % Help: Timothy.Ellmore@uth.tmc.edu
    
    % the name of the ascii file
    fid=fopen(fname,'r');
    
    %header line 1: acquisition information
    hline1 = fgets(fid);
    
    % get the six different fields in the header, store in cell array
    %hd=textscan(hline1,'%s %s %s %s %s %s');
    [hd]=strread(hline1,'%s');
    
    fprintf('\nNihon Kohden ASCII EEG header fields:');
    fprintf('\n-------------------------------------');
    
    % number of timepoints
    [txt,ntpoints]=strread(char(hd{1}),'%s%d','delimiter','=');
    fprintf('\n%s is %d',char(txt),ntpoints);
    
    % number of channels sampled
    [txt,nchannels]=strread(char(hd{2}),'%s%d','delimiter','=');
    fprintf('\nNumber of %s is %d',char(txt),nchannels);
    
    % begin sweep in ms
    [txt,bsweep]=strread(char(hd{3}),'%s%f','delimiter','=');
    fprintf('\n%s is %2.2f',char(txt),bsweep);
    
    % sampling interval in ms
    [txt,sampintms]=strread(char(hd{4}),'%s%f','delimiter','=');
    fprintf('\n%s is %1.2f (or %2.1f Hz)',char(txt),sampintms,(1000./sampintms));
    
    % bins per micro volt
    [txt,binsuV]=strread(char(hd{5}),'%s%f','delimiter','=');
    fprintf('\n%s is %1.2f',char(txt),binsuV);
    
    % start time
    tt=char(hd{6});
    start_time=tt(end-7:end);
    fprintf('\nStart Time is %s\n',start_time);
    
    % header line 2: names of recording channels
    hline2 = fgets(fid);
    
    % channel names as cell array
    %ch_names=textscan(hline2,'%s');
    [ch_names]=strread(hline2,'%s');
    
    % convert to char array
    %ch_names=char(ch_names{1});
    
    % close input file
    fclose(fid);
    
  end


  function nkdata = nkascii2mat(fname)
    % Reads a Nihon Kohden EEG file in ASCII format (fname), converts
    % the floating point ASCII values to 32-bit signed integers, and writes
    % them to disk as a matlab structure file (matfname).
    %
    % The mat file holds a structure nkdata with the following fields:
    %  nkdata.eeg - all the eeg data stored as nchannels-by-npoints matrix
    %  nkdata.multiplier - a multiplier; divide stored value by this to floats
    %  nkdata.num_dpoints - number of data points per channel
    %  nkdata.nchannels - number of recorded channels
    %  nkdata.bsweep - begin sweep (ms)
    %  nkdata.ms_per_sample - ms per data sample
    %  nkdata.binsuV - bins per microvolt
    %  nkdata.start_time - start time of exported data segment
    %  nkdata.ch_names - char array of channel names
    %
    % Example:
    %  nkdata=nkascii2mat('TS003_LFP_SpatialWM.m00');
    %
    % Note:
    %  Data in the NK ASCII file are stored with floating point precision to the hundreth
    %  decimal place. On conversion, each data value is multiplied by 100 in order to store
    %  data as 16 bit integers (storage as 16 bit int rather than 32 bit float saves space).
    %  Therfore, when reading the resultant mat file each data value must be divided by the
    %  nkdata.multiplier, which is given by the command line parameter mult.
    %  You must do this to preserve micovolt units. Here's how:
    %
    %  load TS003_LFP_SpatialWM.mat
    %  nkdata.eeg=nkdata.eeg./nkdata.multiplier;
    %
    % Last modified 9/17/07 by TME
    % Help: Timothy.Ellmore@uth.tmc.edu
    
    % get header information
    [tpoints,nchannels]=nkgetheader(fname);
    
    % the name of the ascii file
    fid=fopen(fname,'r');
    
    % skip header information
    hline1 = fgets(fid);
    hline2 = fgets(fid);
    
    % read file in 10 separate chunks (helps save RAM)
    nsegs=10;
    seg_len=tpoints/nsegs;
    
    fprintf('Will read %d segments each with %d sampled points\n',nsegs,seg_len);
    
    nkdata.eeg=zeros(nchannels,tpoints);
    lastp=1;
    for seg_num=1:nsegs
      
      dc=[];df=[];dtmp=[];
      
      if(seg_num==1)
        dc=textscan(fid,'%f',nchannels*seg_len,'HeaderLines',0);
      else
        dc=textscan(fid,'%f',nchannels*seg_len,'HeaderLines',0);
      end
      
      df=dc{1};
      npoints=length(df)/nchannels;
      dtmp=reshape(df,nchannels,npoints);
      clear df dc;
      % store in cumulative matrix
      nkdata.eeg(1:nchannels,lastp:(lastp+npoints-1))=dtmp;
      clear dtmp df dc;
      
      fprintf('%d to %d, %d percent completed!\n',lastp,lastp+npoints-1,seg_num*nsegs);
      
      lastp=lastp+npoints;
      
    end
    
    fclose(fid);
    
    % store individual pieces of information from header line 1
    [nkdata.num_dpoints,nkdata.nchannels,nkdata.bsweep,nkdata.ms_per_sample,nkdata.binsuV,nkdata.start_time,ch_names]=nkgetheader(fname);
    % store sampling rate in Hz
    nkdata.sampHz=1000./nkdata.ms_per_sample;
    % store channel names
    nkdata.ch_names=ch_names;
    
  end



  function [ttimes,tdurations,tcues]=aligndata(zx,o,io1,io2)
    %% relate series
    tidx=find(zx>0)/frq;
    
    % get marker times
    ttimes=o.mktimes(2:3:end);
    tdurations=o.mktimes(3:3:end);
    tdurations=tdurations-ttimes;
    tcues=o.mktimes(1:3:end);
    
    %find sync sequences
    if(~isempty(io1) && ~isempty(io2))
      %manual alignment
      fprintf('Manual offsets given, using manual offsets...\n');
      dt=tidx(io2)-ttimes(io1);
    else      
      %automatic alignment
      dts=round(diff(ttimes));
      idts1=dts(1:end-3)==5 & dts(2:end-2)==4 & dts(3:end-1)==3 & dts(4:end)==2;
      i1=find(idts1);
      fprintf('Found %i possible sync offset in o-data...\n',length(i1));
      fprintf(' #%i;',i1); fprintf('\n');
      if(length(i1)>1)
        fprintf('Warning: multiple possible sync offset detected in o-data,\n');
        fprintf('         if auto-alignment fails use manual offsets...\n');
      end
      
      dts=round(diff(tidx));
      idts2=dts(1:end-3)==5 & dts(2:end-2)==4 & dts(3:end-1)==3 & dts(4:end)==2;
      i2=find(idts2);
      fprintf('Found %i possible sync offset in nk-data...\n',length(i2));
      fprintf(' #%i;',i2); fprintf('\n');
      if(length(i2)>1)
        fprintf('Warning: multiple possible sync offset detected in nk-data,\n');
        fprintf('         if auto-alignment fails use manual offsets...\n');
      end
      
      if(isempty(i1) || isempty(i2))
        fprintf('Error finding sync sequences, use manual offsets...\n');
        ttimes=[];
        tdurations=[];
        tcues=[];
        return
      end
      
      i1=i1(end);
      fprintf('Choosing offset in o-data #%i\n',i1);
      
      i2=i2(end);
      fprintf('Choosing offset in nk-data #%i\n',i2);
      
      dt=tidx(i2)-ttimes(i1);
    end
    
    % fine-align the series, repeat five times in loop
    % it is important to get this right, or entire series may shift
    for k=1:5
      dd=dist([ttimes+dt,tidx]);
      dd=dd(1:length(ttimes),length(ttimes)+1:end);
      [grb cidx]=min(dd,[],2);
      dt=mean(tidx(cidx)-ttimes);
      fprintf(' Time shift %g sec...\n',dt);
    end
    
    % show result
    figure,plot(ttimes,tidx(cidx)+dt,'o')
    figure,plot(ttimes,ttimes-tidx(cidx)+dt,'-x')    
    hold on
    grid on
    
    % discard mismatches, form result
    xdtdata=(ttimes-tidx(cidx)+dt)';
    xidx=find(abs(xdtdata)<6*std(xdtdata));
    xdtdata=xdtdata(xidx);
    [b bi r]=regress(xdtdata,[ones(length(xidx),1),ttimes(xidx)']);
    edrift=2*std(r);
    fprintf('Max allowed error due to drift %g sec...\n',edrift);
    plot(ttimes([1,end]),b(1)+b(2)*ttimes([1,end])+edrift,'r')
    plot(ttimes([1,end]),(b(1)+b(2)*ttimes([1,end])-edrift),'r')
    
    tfail=abs(ttimes-tidx(cidx)+dt-b(1)-b(2)*ttimes)>edrift;
    fprintf('Failed alignment points %i...\n',sum(tfail));
    plot(ttimes(tfail),ttimes(tfail)-tidx(cidx(tfail))+dt,'ro')
    
    ttimes=tidx(cidx(~tfail));
    tdurations=tdurations(~tfail);
    tcues=tcues(~tfail);
  end


end