function MU=xftr_mui(eegdata,mrkdata,rmarkers)
%mui=xftr_mui(eegdata,mrkdata,rmarkers)
% Calculate the MUI for a BCI target and fft-features using trial-binned 
% distributions of the features for multi-valued target, toolchain 
% (internal) use. Provide EEG data and target data in 'eegdata' and
% 'mrkdata' variables. Use 'rmarkers' to restrict the values in the 
% marker-channel to only such in 'rmarkers'.
%
% Example usage:
%  mui=ftr_mui(eegdata,mrkdata,chid,freqid,[1 2])
%
%Y.Mishchenko (c) 2015

%examples:
% datafiles={'pilot20150625-nk.mat'};
% datafiles={'nkdeney-yuriy-20150916-ofull.mat'};

% predt=0.25;  %epoch pre-length (prior stimulus), sec
% postdt=0.85; %epoch post-length (post stimulus), sec
% predt=0.0;  %epoch pre-length (prior stimulus), sec
% postdt=1.5; %epoch post-length (post stimulus), sec
% chs=1:21;   %data channels

M=13;       %number of samples for histogram binning of features
if(nargin<3) rmarkers=[]; end

%% Load data

% %select data
% [ft ftmrk]=ftprep(datafiles,predt,postdt,chs,cmode);
% [eegdata,mrkdata]=make_features(ft,ftmrk,'all');
% chid=ft.chid;
% freqid=ft.freqid;


if(isempty(rmarkers))
  signals=unique(mrkdata);
else
  signals=rmarkers;
end

mrkdata(~ismember(mrkdata,signals))=0;
nn=min(size(eegdata,1),10000);    % max number of samples to use is 10k
features=1:size(eegdata,2);


%% calculate relations matrices
nfeatures=length(features);
nS=size(eegdata,1);
MU=zeros(nfeatures,1);    %this is MUI array
for i=1:nfeatures
    eeg1=eegdata(:,features(i));
    mrk2=mrkdata;
    
    id=randperm(nS);
    xeeg1=eeg1(id(1:nn));
    xmrk2=mrk2(id(1:nn));
    
    MU(i)=MUIz2(xeeg1',xmrk2',M);    
end

end
