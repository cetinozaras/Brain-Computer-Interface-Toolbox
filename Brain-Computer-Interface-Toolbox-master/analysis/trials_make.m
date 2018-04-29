function trials=trials_make(o,dt1,dt2)
%trials=trials_make(o,dt1,dt2)
% Make a cell array of trial matrices for EEG recording data o. 
% Example usage:
%  tr=trials_make(o,1,2)
% Each trial matrix is a 3D matrix with the dimensions 
% n_samples x n_time x n_channels. dt1 and dt2 are the length
% of time in the EEG recording (in seconds) before and after 
% a given trial stimulus onset to include in the trial matrix.
%
%Y.Mishchenko (c) 2015
dt1=round(dt1*o.sampFreq);
dt2=round(dt2*o.sampFreq);

nch=size(o.data,2);
dt=dt1+dt2;

fprintf('Selecting trials from EEG data...\n');

trialids=unique(o.marker(o.marker>0));
ntrial=length(trialids);

fprintf('Found %i trial types:',ntrial);
fprintf('\n %i',trialids);
fprintf('\ncontinuing...\n');

trials=cell(1,ntrial);
for i=1:ntrial
  trid=trialids(i);
  
  %find stimulus onset times
  idx=find(diff(o.marker==trid)>0);
  idxon=idx(1:end-1);
  %remove partial epochs
  idxon=idxon(idxon>dt1+1 & idxon<o.nS-dt2);
  nn=length(idxon);
  
  fprintf('Found %i samples for %i...\n',nn,trid);
  
  eegsamples=zeros(nn,dt,nch);
  for k=1:nn
    tp=idxon(k);
    tstart=tp-dt1+1;
    tend=tp+dt2;
    
    eegsamples(k,:,:)=o.data(tstart:tend,:);
  end
  
  trials{i}=eegsamples;  
end
  
end