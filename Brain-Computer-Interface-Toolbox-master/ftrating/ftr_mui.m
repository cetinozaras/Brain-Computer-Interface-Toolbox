function [MU,chid,freqid]=ftr_mui(datafiles,predt,postdt,chs,cmode,rmarkers)
%mui=ftr_mui(datafiles,predt,postdt,chs,cmode,rmarkers)
% Calculate the MUI for a BCI target and fft-features using trial-binned 
% distributions of the features for multi-valued target. 'datafiles' is a 
% cell array of file names pointing to the eeg data to be processed. 
% The eeg data in all data-files should be uniformly stored in variable 
% 'o', in emotiv output-file format. 'predt' and 'postdt' are 
% before and after stimulus-onset epoch lengths, in seconds. 'chs' is 
% the array of indexes of the useful eeg-data channels in the data. 
% Produces array 'mui' of mutual information estimates between each 
% feature in [ft.eegpow,ft.bandpow,ft.pow,ft.powlog,ft.real,ft.imag] and 
% the marker data, where ft is the output structure of ftprep, see
% ftprep.m. 'cmode' is the common mode to be subtracted from all channels 
% before calculating fft-features, see ftprep.m. Use 'rmarkers' to 
% restrict the values in the marker-channel to only that in 'rmarkers'.
%
% Example usage:
%  mui=ftr_mui({'nkdeney-example.mat'},0.0,0.85,1:21,[],[1 2])
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
if(nargin<5) cmode=[]; end
if(nargin<6) rmarkers=[]; end

%% Load data
fprintf('Reading data...\n');

%select data
[ft ftmrk]=ftprep(datafiles,predt,postdt,chs,cmode);
[eegdata,mrkdata]=make_features(ft,ftmrk,'all');
chid=ft.chid;
freqid=ft.freqid;


if(isempty(rmarkers))
  signals=unique(ftmrk);
else
  signals=rmarkers;
end
mrkdata(~ismember(mrkdata,signals))=0;
nn=min(size(eegdata,1),10000);    % max number of distribution samples 10k
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
        
    fprintf('Evaluating feature %i...\n',features(i));
    %KL algorithm (MUIz) is too noisy in 1D (?)
    %use histogram binning instead (MUIz2)
    %MU(i)=MUIz(xeeg1',xmrk2');        
    MU(i)=MUIz2(xeeg1',xmrk2',M);
    fprintf('MUI: %g\n',MU(i));
end

%MUI is >=0 by definition
figure,plot(max(0,MU))

end
