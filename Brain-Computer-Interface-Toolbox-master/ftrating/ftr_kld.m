function KL=ftr_kld(datafiles,predt,postdt,chs,cmode,tgtmrk)
%kld=ftr_kld(datafiles,predt,postdt,chs,cmode,tgtmrk)
% Calculate the KL-divergence measure for a BCI target and fft-features. 
% 'datafiles' is a cell array of file names pointing to the eeg data to 
% be processed. The eeg data in all data-files should be uniformly stored 
% in variable 'o', in emotiv output-file format. 'predt' and 'postdt' are 
% before and after stimulus-onset epoch lengths, in seconds. 'chs' is 
% the array of indexes of the useful eeg-data channels in the data. 
% Produces array 'kld' of KL-divergence estimates for each feature in 
% [ft.eegpow,ft.bandpow,ft.pow,ft.powlog,ft.real,ft.imag] with respect to
% marker==tgtmrk, where ft is the output structure of ftprep, see ftprep.m. 
% 'cmode' is the common mode to be subtracted from all channels before 
% calculating fft-features, see ftprep.m. Use 'tgtmrk' selects one value 
% in the marker-channel.
%
% Example usage:
%  kld=ftr_kld({'nkdeney-example.mat'},0.0,0.85,1:21,[],2)
%
%Y.Mishchenko (c) 2015

%examples
% datafiles={'pilot20150625-nk.mat'};
% datafiles={'nkdeney-yuriy-20150916-ofull.mat'};

% predt=0.00;  %epoch pre-length (prior stimulus), sec
% postdt=1.50; %epoch post-length (post stimulus), sec
% chs=1:21;   %data channels

M=13;       %number of samples for histogram binning of features

if(nargin<5) cmode=[]; end
if(nargin<6) tgtmrk=2; end

%% Load data
fprintf('Reading data...\n');

%select data
[ft ftmrk]=ftprep(datafiles,predt,postdt,chs,cmode);
[eegdata,mrkdata]=make_features(ft,ftmrk,'all');
features=1:size(eegdata,2);    
nn=min(size(eegdata,1),10000);  %max number of distribution samples 10k

                
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
    
    fprintf('Evaluating channel %i...\n',features(i));
    KL(i)=KLDz(xeeg1',xmrk2',M);    
    fprintf('KL-div: %g\n',KL(i));
end

%KL-divergence is >=0 by definition
figure,plot(max(0,KL))

end
