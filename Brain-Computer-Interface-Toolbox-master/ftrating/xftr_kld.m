function KL=xftr_kld(eegdata,mrkdata,tgtmrk)
%kld=xftr_kld(eegdata,mrkdata,chid,freqid,tgtmrk)
% Calculate the KL-divergence measure for a BCI target and fft-features, 
% toolchain (internal) use. Provide EEG data and target data in 'eegdata' 
% and 'mrkdata' variables. Use 'tgtmrk' selects one value in the marker-
% channel.
%
% Example usage:
%  kld=ftr_kld(eegdata,mrkdata,[],[],2)
%
%Y.Mishchenko (c) 2015

%examples
% datafiles={'pilot20150625-nk.mat'};
% datafiles={'nkdeney-yuriy-20150916-ofull.mat'};

% predt=0.00;  %epoch pre-length (prior stimulus), sec
% postdt=1.50; %epoch post-length (post stimulus), sec
% chs=1:21;   %data channels

M=13;       %number of samples for histogram binning of features

if(nargin<3) tgtmrk=1; end

%% Load data
% %select data
% [ft ftmrk]=ftprep(datafiles,predt,postdt,chs,cmode);
% [eegdata,mrkdata]=make_features(ft,ftmrk,'all');
nn=min(size(eegdata,1),10000);  %max number of samples to use is 10k
features=1:size(eegdata,2);    

                
%% calculate relations matrices
nfeatures=length(features);
nS=size(eegdata,1);
KL=zeros(nfeatures,1);    %this is KL values
for i=1:nfeatures
    eeg1=eegdata(:,features(i));
    mrk2=(mrkdata==tgtmrk);
    
    id=randperm(nS);
    xeeg1=eeg1(id(1:nn));
    xmrk2=mrk2(id(1:nn));

    KL(i)=KLDz(xeeg1',xmrk2',M);
end

end
