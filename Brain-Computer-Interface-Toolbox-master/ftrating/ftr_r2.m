function COR=ftr_r2(datafiles,predt,postdt,chs,cmode,tgtmrk)
%r2=ftr_r2(datafiles,predt,postdt,chs,cmode,tgtmrk)
% Calculate the correlation measure between a BCI target and fft-features. 
% 'datafiles' is a cell array of file names pointing to the eeg data to 
% be processed. The eeg data in all data-files should be uniformly stored 
% in variable 'o', in emotiv output-file format. 'predt' and 'postdt' are 
% before and after stimulus-onset epoch lengths, in seconds. 'chs' is 
% the array of indexes of the useful eeg-data channels in the data. 
% Produces array 'r2' of correlation coefficient squares between each 
% feature in [ft.eegpow,ft.bandpow,ft.pow,ft.powlog,ft.real,ft.imag] and 
% binary variable marker==tgtmrk, where ft is the output structure of 
% ftprep, see ftprep.m. 'cmode' is the common mode to be subtracted from 
% all channels before calculating fft-features, see ftprep.m. Use 
% 'tgtmrk' selects one value in the marker-channel.
%
% Example usage:
%  r2=ftr_r2({'nkdeney-example.mat'},0.0,0.85,1:21,[],2);
%
%Y.Mishchenko (c) 2015

%examples:
% datafiles={'pilot20150625-nk.mat'};
% datafiles={'nkdeney-yuriy-20150916-ofull.mat'};

% predt=0.00;  %epoch pre-length (prior stimulus), sec
% postdt=1.5; %epoch post-length (post stimulus), sec
% chs=1:21;   %data channels

if(nargin<5) cmode=[]; end
if(nargin<6) tgtmrk=2; end

%% Load data
fprintf('Reading data...\n');

%select data
[ft,ftmrk]=ftprep(datafiles,predt,postdt,chs,cmode);
[eegdata,mrkdata]=make_features(ft,ftmrk,'all');

COR=xftr_r2(eegdata,mrkdata,tgtmrk);

fprintf('Corr2: %g\n',COR);
figure,plot(COR)

end