function [MU COR]=muivsedst(datafile,dst,channels,dstep)
%[MUI, COR]=muivsedst(datafile,dstfile,channels,dstep)
% Construct the graph of mutual information vs. distance between all
% pairs of electrodes in the EEG o-data file 'datafile', with the
% distances between the electrodes specified in matrix 'dst'. 'channels' 
% is a list of ids of the channels contained in 'dst', see below. 
% 'dstep' specifies the discretization error for the continuous EEG
% signal.
%
% The distances between the electrodes need to be specified in matrix 
% 'dst' with the electrodes listed in the order specified in 'channels'. 
% Only the electrodes mentioend in 'channels' need to be included in 
% 'dst', thus size(dst)=[length(channels),length(channels)]. If 
% 'channels' is not given, 'dst' is assumed to list all electrodes 
% from 'datafile' excluding the A1 and A2 electrodes.
%
% The mutual information matrix and the correlation matrix are calculated
% for the raw signal in two EEG electrodes in time-domain, graphs these
% vs. the scalp-geodesic distance between the electrodes. 
%
% Example usage:
%   [mui,cor]=muivsedst('pilot20150625-nk.mat',dst,chs,0.01);
%
%Y.Mishchenko (c) 2015

%% SETTINGS
%data file name
% fname='pilot20150625-nk.mat';
% fname='nkdeney-yuriy-20150916-ofull.mat';

method=2;   %choose entropy estimation method, 
            %1 - LK method, 2 - histogram binning

M=33;       %number of samples for histogram binning of features

%% LOAD DATA
fprintf('Reading data...\n');
%load data
R=load(datafile);
o=R.o;
eegdata=o.data;  %select data source, time-samples x channels
if nargin<3 || isempty(channels)    
    channels=[1:10,13:21]; %exclude A1,A2 channels
end

% ----!!!----
if nargin<4 || isempty(dstep)
  dstep=0.01;     %set data discretization step, important
                  %SET THIS PROPERLY FOR CORRECT RESULTS!
                  %dstep=0.5128 for EMOTIV, dstep=0.01 for NIHON KOHDEN
end
% ----!!!----
           
%select number of samples from the distribution to draw into MUI estimator
if(method==1)
  nn=1000;
elseif(method==2)
  nn=100000;
end
                

%% MAIN LOOP
nch=length(channels);
nS=size(eegdata,1);
MU=zeros(nch,nch);     %this is MUI matrix
COR=zeros(nch,nch);    %this is correlations matrix
for i=1:nch
  for j=1:nch    
    %get EEG signal, time-domain
    eeg1=eegdata(:,channels(i));
    eeg2=eegdata(:,channels(j));
    
    %get nn joint samples from the two EEG signals
    id=randperm(nS);
    xeeg1=eeg1(id(1:nn));
    xeeg2=eeg2(id(1:nn));
    
    %add additional randomization, with discretization-step
    %(EEG signal doesn't really contain information smaller 
    %than the discretization step, affects MUI calculation)
    xeeg1=xeeg1+dstep*(rand(nn,1)-0.5);
    xeeg2=xeeg2+dstep*(rand(nn,1)-0.5);
    
    fprintf('Evaluating channels %i-%i...\n',channels(i),channels(j));
    if(method==1)
      %uses KL algorithm
      MU(i,j)=MUI(xeeg1',xeeg2');    
    elseif(method==2)
      %users histogram-binning algorithm
      [mui hxy hx]=MUI2(xeeg1',xeeg2',M);
      
      %formally MUI(X,X)=Inf for continous variables,
      %here we replace MUI(X,X)->H(X)
      if(i==j)
          MU(i,j)=hx;
      else
        MU(i,j)=mui;
      end
    end
    COR(i,j)=corr(xeeg1,xeeg2)^2;
    fprintf('Corr2: %g\n',COR(i,j));
    fprintf('D: %g cm\n',dst(i,j));    
  end
end

%% GRAPHS
% mui & correlation matrices
figure,imagesc(MU),colorbar,title('MUI')
figure,imagesc(COR),colorbar,title('CORR2')

% mui & correlation vs. electrode-distance scatter plots
figure,plot(dst(:),MU(:),'.'),title('MUI')
figure,plot(dst(:),COR(:),'.'),title('CORR2')

% mui & correlation vs. electrode-distance errorbar plots
i5=find(channels==5);
i6=find(channels==6);

maxdst=floor(max(dst(:)));
in=MU; 
%C3 and C4 are artificially correlated in NK
%via 0V being 1.22*(C3+C4)/2, do not take into account here
in(i5,i6)=0; in(i6,i5)=0; 
out=zeros(2,maxdst+1);
for i=0:maxdst
  indexes=find(dst>i-1 & dst<i+1);
  values=in(indexes);
  out(1,i+1)=mean(values);
  out(2,i+1)=std(values);
end
figure,errorbar(0:maxdst,out(1,:),out(2,:),'d-'),title('MUI')
axis([-1 maxdst 0 max(out(1,:)+out(2,:))+0.1])

in=COR; 
in(i5,i6)=0; in(i6,i5)=0; 
out=zeros(2,maxdst+1);
for i=0:maxdst
  indexes=find(dst>i-1 & dst<i+1);
  values=in(indexes);
  out(1,i+1)=mean(values);
  out(2,i+1)=std(values);
end
figure,errorbar(0:maxdst,out(1,:),out(2,:),'d-'),title('CORR2')
axis([-1 maxdst 0 max(out(1,:)+out(2,:))+0.1])

end
