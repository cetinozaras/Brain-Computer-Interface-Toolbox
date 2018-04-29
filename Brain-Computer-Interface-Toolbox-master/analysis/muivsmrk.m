function [MU COR]=muivsmrk(datafile,signals,dstep)
%[MUI, COR]=muivsedst(datafile,dstfile)
% Construct the graph of mutual information vs. distance between all
% electrodes in the EEG o-data file 'datafile' and the marker signal. 
%
% The mutual information and the correlations are calculated for the raw 
% signal in EEG electrodes in time-domain and the target marker. 
%
% Example usage:
%   [mui, cor]=muivsedst('pilot20150625-nk.mat','eegdistances_nk',0.01);
%
%Y.Mishchenko (c) 2015


%% SETTINGS

%data file name
% fname={'pilot20150625-nk.mat'};
% fname='nkdeney-yuriy-20150916-ofull.mat';

M=13;       %number of samples for histogram binning of features

%% LOAD DATA
fprintf('Reading data...\n');

%load data
R=load(datafile);
o=R.o;

eegdata=o.data; %select data source, time-samples x channels
mrkdata=o.marker;
channels=1:21;  %select informative channels, exclude A1,A2
nn=20000;       %select number of random samples to draw for MUI estimator

%target signals to include vs. all others
if nargin<2 || isempty(signals)
  signals=1;
end

% ----!!!----
if nargin<3 || isempty(dstep)
  dstep=0.01;     %set data discretization step, important
                  %SET THIS PROPERLY FOR CORRECT RESULTS!
                  %dstep=0.5128 for EMOTIV, dstep=0.01 for NIHON KOHDEN
end
% ----!!!----
                
idx=ismember(mrkdata,signals);
mrkdata(~idx)=0;
                
%% calculate relations matrices
nch=length(channels);
nS=size(eegdata,1);
MU=zeros(nch,1);    %this is MUI matrix
COR=zeros(nch,1);   %this is correlations
for i=1:nch
    eeg1=eegdata(:,channels(i));
    mrk2=mrkdata;
    
    id=randperm(nS);
    xeeg1=eeg1(id(1:nn));
    xmrk2=mrk2(id(1:nn));
    
    %additional randomization within discretization-step
    xeeg1=xeeg1+dstep*(rand(nn,1)-0.5);
    
    fprintf('Evaluating channel %i...\n',channels(i));
    %%use KL algorithm, too noise in 1D (?)
    %MUc(i)=MUIz(xeeg1',xmrk2');    
    %use histogram binning
    MU(i)=MUIz2(xeeg1',xmrk2',M);
    COR(i)=corr(xeeg1,xmrk2~=0)^2;
    fprintf('MUI: %g\n',MU(i));
    fprintf('COR: %g\n',COR(i));
end

figure,plot(MU)
figure,plot(COR)
end
