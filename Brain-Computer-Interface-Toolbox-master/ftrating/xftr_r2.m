function COR=xftr_r2(eegdata,mrkdata,tgtmrk)
%r2=xftr_r2(eegdata,mrkdata,tgtmrk)
% Calculate correlation measure between BCI target and fft-features, 
% (toolchain - internal use). Provide EEG data and target data in 'eegdata' 
% and 'mrkdata' variables. Use 'tgtmrk' selects one value in the marker-
% channel.
%
% Uses the Pearson correlation square r^2 for a two-target tgtmrk and 
% the Intraclass Correlation Coefficient for higher cardinality tgtmrk.
%
% Example usage:
%  kld=xftr_r2(eegdata,mrkdata,[1,2])
%
%Y.Mishchenko (c) 2015

if(nargin<3) tgtmrk=1; end

%% Load data
% %select data
% [ft ftmrk]=ftprep(datafiles,predt,postdt,chs,cmode);
% [eegdata,mrkdata]=make_features(ft,ftmrk,'all');
nn=min(size(eegdata,1),10000);  %max number of samples is 10k
features=1:size(eegdata,2);    

                
%% calculate feature-marker correlations
nfeatures=length(features);
ntargets=length(tgtmrk);
nS=size(eegdata,1);
COR=zeros(nfeatures,1);    %this is the correlations array
if ntargets==2
  idx=find(ismember(mrkdata,tgtmrk));
  eegdata=eegdata(idx,:);
  mrkdata=mrkdata(idx);
  tgtmrk=tgtmrk(1);
elseif ntargets>2
  groups_idx=cell(1,ntargets);
  groups_n=zeros(1,ntargets);
  for i=1:ntargets
    groups_idx{i}=find(mrkdata==tgtmrk(i));
    groups_n(i)=length(groups_idx{i});
  end
  ntot=sum(groups_n);
  groups_n=groups_n/ntot;
end
for i=1:nfeatures
  eeg1=eegdata(:,features(i));  
  if ntargets<=2  
    mrk2=(mrkdata==tgtmrk);
    r2=corr(eeg1,mrk2)^2;
  else
    mns=zeros(1,ntargets);
    vars=zeros(1,ntargets);
    for j=1:ntargets
      mns(j)=mean(eeg1(groups_idx{j}));
      vars(j)=var(eeg1(groups_idx{j}),1);
    end
    %n-weighted variance of means
    varmns=var(mns,groups_n);
    vareps=sum(groups_n.*vars);
    r2=varmns/vareps;
  end  
  COR(i)=r2;
end

end